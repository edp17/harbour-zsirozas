#include "GameEngine.h"

#include <algorithm>
#include <random>
#include <QVariantMap>
#include <QDebug>

// #define ZSIROZAS_TRACE 1
#if defined(ZSIROZAS_TRACE)
  #define TRACE(...) qDebug() << __VA_ARGS__
#else
  #define TRACE(...) do {} while (0)
#endif

static std::mt19937 rng{ std::random_device{}() };

QVariantList GameEngine::toVariantList(const QVector<Card>& v)
{
    QVariantList out;
    out.reserve(v.size());
    for (const Card& c : v) {
        QVariantMap m;
        m["rank"] = c.rank;
        m["suit"] = c.suit;
        m["id"] = c.id();
        m["isZsir"] = c.isZsir();
        m["playedBy"] = c.playedBy;
        out << m;
    }
    return out;
}

QVariantList GameEngine::playerHand() const { return toVariantList(m_player); }
QVariantList GameEngine::cpuHand() const { return toVariantList(m_cpu); }
QVariantList GameEngine::tableCards() const { return toVariantList(m_table); }
QVariantList GameEngine::playerWonCards() const { return toVariantList(m_playerWon); }
QVariantList GameEngine::cpuWonCards() const { return toVariantList(m_cpuWon); }

GameEngine::GameEngine(QObject* parent) : QObject(parent)
{
    m_aiTimer.setSingleShot(true);
    m_pileTimer.setSingleShot(true);

    connect(&m_aiTimer, &QTimer::timeout, this, [this]() {
        if (m_turn != Turn::Cpu) return;
        if (!m_roundResult.isEmpty()) return;
        if (m_pilePending) return;
        if (m_cpu.isEmpty()) {
            // If there's an active pile, resolve it to last hitter.
            if (!m_table.isEmpty() && !m_pilePending) {
                scheduleRoundWin(m_lastHitter);
            } else {
                // No pile: if player still has cards, give them the turn; else finish.
                if (!m_player.isEmpty()) {
                    m_turn = Turn::Player;
                    emit stateChanged();
                } else if (isGameOverCondition()) {
                    finishGame();
                }
            }
            return;
        }

        const int idx = chooseCpuIndex();
        if (idx < 0) return;
        applyMove(Turn::Cpu, idx);
    });

    connect(&m_pileTimer, &QTimer::timeout, this, [this]() {
        commitPile();
    });

    newGame();
}

void GameEngine::setAiPlayDelay(int ms)
{
    if (m_aiPlayDelay == ms) return;
    m_aiPlayDelay = ms;
    emit aiPlayDelayChanged();
}

bool GameEngine::playerInputEnabled() const
{
    return m_roundResult.isEmpty()
        && (m_turn == Turn::Player)
        && !m_inputLocked
        && !m_pilePending;
}

bool GameEngine::canLeave() const
{
    if (!playerInputEnabled()) return false;
    if (m_movesInPile < 2) return false;
    if (m_haveToMove) return false;                 // decision phase
    if (m_roundStarter != Turn::Player) return false; // starter must be human

    // Decision only matters if someone else currently controls the pile
    if (m_lastHitter == Winner::Player) return false;

    // If player can't hit, engine should auto-resolve anyway
    return handHasHitCard(m_player);
}

void GameEngine::initDeck()
{
    QVector<Card> deck;
    deck.reserve(32);

    // Hungarian deck: 7..Ace (14), 4 suits
    for (int s = 0; s < 4; ++s) {
        for (int r = 7; r <= 14; ++r) {
            Card c;
            c.rank = r;
            c.suit = s;
            deck.append(c);
        }
    }

    std::shuffle(deck.begin(), deck.end(), rng);
    m_talon = deck;
}


void GameEngine::refillHands(Winner firstDraws)
{
    const int talonBefore = m_talon.size();
    const int pBefore = m_player.size();
    const int cBefore = m_cpu.size();

    int drewPlayer = 0;
    int drewCpu = 0;

    auto drawOne = [&](QVector<Card>& hand, bool isPlayer) {
        if (!m_talon.isEmpty()) {
            hand.append(m_talon.takeLast());
            if (isPlayer) ++drewPlayer; else ++drewCpu;
        }
    };

    auto needCard = [&](const QVector<Card>& hand) -> bool {
        return hand.size() < 4;
    };

    const bool firstIsPlayer = (firstDraws == Winner::Player);
    QVector<Card>* first  = firstIsPlayer ? &m_player : &m_cpu;
    QVector<Card>* second = firstIsPlayer ? &m_cpu    : &m_player;

    // Alternate draws: first, second, first, second... until both are full or talon empty.
    while (!m_talon.isEmpty() && (needCard(*first) || needCard(*second))) {
        if (needCard(*first) && !m_talon.isEmpty())
            drawOne(*first, firstIsPlayer);
        if (needCard(*second) && !m_talon.isEmpty())
            drawOne(*second, !firstIsPlayer);
    }

    // --- Invariant checks (debug/warning) ---
    const int talonAfter = m_talon.size();

    // Talon should remain even in 2-player Zsírozás (32-card deck).
    if ((talonAfter % 2) != 0) {
        qWarning() << "[BUG] Talon became odd after refill:"
                   << "before=" << talonBefore << "after=" << talonAfter;
    }

    // Both players should draw the same number of cards after each pile capture.
    if (drewPlayer != drewCpu) {
        qWarning() << "[BUG] Unequal draws in refillHands:"
                   << "drewPlayer=" << drewPlayer << "drewCpu=" << drewCpu
                   << "firstDraws=" << (firstDraws == Winner::Player ? "Player" : "CPU")
                   << "talonBefore=" << talonBefore << "talonAfter=" << talonAfter
                   << "handBefore(P,C)=" << pBefore << cBefore
                   << "handAfter(P,C)=" << m_player.size() << m_cpu.size();
    }

    // Hand sizes should match after refill (normally equal in 2-player play).
    if (m_player.size() != m_cpu.size()) {
        qWarning() << "[BUG] Hand sizes diverged after refill:"
                   << "player=" << m_player.size() << "cpu=" << m_cpu.size()
                   << "talonAfter=" << talonAfter;
    }
}

bool GameEngine::isHitRank(int rank) const
{
    // hit matches FIRST card of pile, or is a 7
    return (m_cardToHit >= 0) && (rank == m_cardToHit || rank == 7);
}

bool GameEngine::handHasHitCard(const QVector<Card>& hand) const
{
    if (m_cardToHit < 0) return false;
    for (const Card& c : hand) {
        if (c.rank == m_cardToHit || c.rank == 7)
            return true;
    }
    return false;
}

void GameEngine::newGame()
{
    m_aiTimer.stop();
    m_pileTimer.stop();

    m_inputLocked = false;
    m_pilePending = false;

    m_playerWon.clear();
    m_cpuWon.clear();
    m_table.clear();
    m_player.clear();
    m_cpu.clear();

    m_lastTrick.clear();
    m_roundResult.clear();

    m_playerPoints = 0;
    m_cpuPoints = 0;

    m_turn = Turn::Player;

    m_cardToHit = -1;
    m_haveToMove = true;
    m_movesInPile = 0;
    m_roundStarter = Turn::Player;
    m_lastHitter = Winner::Player;

    m_lastPlayedWasSeven = false;
    m_lastPlayedBy = Turn::Player;

    m_lastPileWinner = Winner::Player;

    initDeck();
    refillHands(Winner::Player);

    updateStatusText();

    emit statusChanged();
    emit lastTrickChanged();
    emit roundResultChanged();
    emit scoreChanged();
    emit stateChanged();
}

void GameEngine::playCard(int handIndex)
{

    // If "Let go" is offered, only HIT cards are legal plays (otherwise use Let go).
    if (canLeave()) {
        if (handIndex < 0 || handIndex >= m_player.size()) return;
        const Card& c = m_player[handIndex];
        if (!isHitRank(c.rank)) return;
    }

    if (!m_roundResult.isEmpty()) return;
    if (!playerInputEnabled()) return;

    m_inputLocked = true;
    emit stateChanged();

    applyMove(Turn::Player, handIndex);

    if (!m_pilePending) {
        m_inputLocked = false;
        emit stateChanged();
    }
}

void GameEngine::playerLeave()
{
    if (!canLeave())
        return;

    // leaving ends pile immediately; winner is last hitter
    scheduleRoundWin(m_lastHitter);
}

void GameEngine::applyMove(Turn who, int handIndex)
{
    QVector<Card>& hand = (who == Turn::Player) ? m_player : m_cpu;
    if (handIndex < 0 || handIndex >= hand.size()) return;

    // Cancel any scheduled actions; a real play is happening now
    m_aiTimer.stop();
    m_pileTimer.stop();
    m_pilePending = false;

    Card played = hand.takeAt(handIndex);
    played.playedBy = (who == Turn::Cpu) ? 1 : 0;
    m_table.append(played);

    // Endgame special tracking (from your previous engine)
    m_lastPlayedWasSeven = (played.rank == 7);
    m_lastPlayedBy = who;

////    qDebug() << "[applyMove]" << (who == Turn::Player ? "Player" : "CPU")
////             << "played" << played.rank << "tableSizeNow=" << m_table.size();

    advanceAfterPlay(who, played.rank);
}

void GameEngine::advanceAfterPlay(Turn whoJustPlayed, int playedRank)
{
    m_movesInPile++;

    // First card defines pile
    if (m_movesInPile == 1) {
        m_cardToHit = playedRank;
        m_roundStarter = whoJustPlayed;
        m_lastHitter = (whoJustPlayed == Turn::Player) ? Winner::Player : Winner::Cpu;

        m_haveToMove = true;

        // Next player must respond
        m_turn = (whoJustPlayed == Turn::Player) ? Turn::Cpu : Turn::Player;

        updateStatusText();
        emit statusChanged();
        emit stateChanged();

        // After the first card, the next player is in forced-hit phase.
        // If they have no legal hit, auto-win goes to last hitter (the starter).
        const QVector<Card>& responderHand = (m_turn == Turn::Player) ? m_player : m_cpu;
        if (responderHand.isEmpty()) {
            scheduleRoundWin(m_lastHitter);
            return;
        }

        maybeScheduleCpuMove();
        return;
    }

    // Update last hitter if this was a hit
    if (isHitRank(playedRank)) {
        m_lastHitter = (whoJustPlayed == Turn::Player) ? Winner::Player : Winner::Cpu;
    }

    // If this play was NOT a hit (and it's not the opening lead), the pile ends now.
    // Winner is the last hitter.
    if (m_movesInPile >= 2 && !isHitRank(playedRank)) {
        scheduleRoundWin(m_lastHitter);
        return;
    }

    // Advance turn
    m_turn = (whoJustPlayed == Turn::Player) ? Turn::Cpu : Turn::Player;

    // In 2-player, “round end” is simply “back to starter”
    const bool backToStarter = (m_turn == m_roundStarter);

    if (backToStarter) {
        // Starter decision phase
        m_haveToMove = false;

        // If starter is also the last hitter, pile is auto-won
        const Winner starterW = (m_roundStarter == Turn::Player) ? Winner::Player : Winner::Cpu;
        if (m_lastHitter == starterW) {
            scheduleRoundWin(m_lastHitter);
            return;
        }

        // If starter cannot hit cardToHit, auto-win for last hitter
        const QVector<Card>& starterHand = (m_roundStarter == Turn::Player) ? m_player : m_cpu;
        if (!handHasHitCard(starterHand)) {
            scheduleRoundWin(m_lastHitter);
            return;
        }

        // Otherwise starter gets choice: play any card OR leave
        updateStatusText();
        emit statusChanged();
        emit stateChanged();

        maybeScheduleCpuMove();
        return;
    }

    updateStatusText();
    emit statusChanged();
    emit stateChanged();

    maybeScheduleCpuMove();
}

void GameEngine::scheduleRoundWin(Winner winner)
{
    if (m_table.isEmpty())
        return;

    m_aiTimer.stop();

    m_pendingWinner = winner;
    m_pilePending = true;
    m_inputLocked = true;

    if (m_table.size() == 1) {
        qWarning() << "[BUG-scheduleRoundWin()] Attempted to resolve a 1-card pile; refusing.";
        return;
    }

    resolvePileAfterDelay();
    emit stateChanged();
}

void GameEngine::resolvePileAfterDelay()
{
////    qDebug() << "[resolvePileAfterDelay] pending=" << m_pilePending
////             << "winner=" << (m_pendingWinner == Winner::Player ? "Player" : "CPU")
////             << "delay=" << m_pileDelayMs;

    m_pileTimer.stop();
    m_pileTimer.start(m_pileDelayMs);
}

void GameEngine::commitPile()
{
////    qDebug() << "[pileTimer timeout] pending=" << m_pilePending << "tableSize=" << m_table.size();

    if (!m_pilePending)
        return;

    if (m_table.isEmpty()) {
        m_pilePending = false;
        m_inputLocked = false;
        emit stateChanged();
        return;
    }

    const Winner winner = m_pendingWinner;
    m_pilePending = false;

    if (m_table.size() == 1) {
        qWarning() << "[BUG-commitPile()] Attempted to resolve a 1-card pile; refusing.";
        return;
    }

    capturePile(winner);

    // Start next pile with the winner as leader
    startNextPileWithLeader(winner);

    if (isGameOverCondition()) {
        finishGame();
        m_inputLocked = false;
        updateStatusText();
        emit statusChanged();
        emit stateChanged();
        return;
    }

    m_inputLocked = false;
    updateStatusText();
    emit statusChanged();
    emit stateChanged();

    maybeScheduleCpuMove();
}

void GameEngine::capturePile(Winner winner)
{
    int z = 0;
    for (const Card& c : m_table) {
        if (c.isZsir())
            z += 10;
    }

    if (winner == Winner::Player) {
        m_playerPoints += z;
        m_playerWon += m_table;
        m_lastPileWinner = Winner::Player;
        m_lastTrick = QStringLiteral("You won the trick");
    } else {
        m_cpuPoints += z;
        m_cpuWon += m_table;
        m_lastPileWinner = Winner::Cpu;
        m_lastTrick = QStringLiteral("AI won the trick");
    }

    m_table.clear();
    refillHands(winner);

    emit scoreChanged();
    emit lastTrickChanged();
}

void GameEngine::startNextPileWithLeader(Winner leader)
{
    // Reset pile state
    m_cardToHit = -1;
    m_movesInPile = 0;
    m_haveToMove = true;

    m_turn = (leader == Winner::Player) ? Turn::Player : Turn::Cpu;

    // If the leader has no cards, give turn to the other player (if they do have cards)
    if (m_turn == Turn::Player && m_player.isEmpty() && !m_cpu.isEmpty())
        m_turn = Turn::Cpu;
    else if (m_turn == Turn::Cpu && m_cpu.isEmpty() && !m_player.isEmpty())
        m_turn = Turn::Player;

    m_roundStarter = m_turn;
    m_lastHitter = leader;
}

void GameEngine::maybeScheduleCpuMove()
{
    if (m_turn != Turn::Cpu) return;
    if (!m_roundResult.isEmpty()) return;
    if (m_pilePending) return;
    if (m_cpu.isEmpty()) {
        // If there's an active pile, resolve it to last hitter.
        if (!m_table.isEmpty() && !m_pilePending) {
            scheduleRoundWin(m_lastHitter);
        } else {
            // No pile: if player still has cards, give them the turn; else finish.
            if (!m_player.isEmpty()) {
                m_turn = Turn::Player;
                emit stateChanged();
            } else if (isGameOverCondition()) {
                finishGame();
            }
        }
        return;
    }

    m_aiTimer.stop();
    m_aiTimer.start(m_aiPlayDelay);
}

int GameEngine::chooseCpuIndex() const
{
    if (m_cpu.isEmpty()) return -1;

    if (m_movesInPile == 0) return 0;

    // Prefer a hit if available (rank==cardToHit or 7)
    for (int i = 0; i < m_cpu.size(); ++i)
        if (isHitRank(m_cpu[i].rank)) return i;

    // Else play any card
    return 0;
}

void GameEngine::updateStatusText()
{
    if (!m_roundResult.isEmpty()) {
        m_status.clear();
        return;
    }

    if (m_pilePending) {
        m_status = QStringLiteral("Resolving...");
        return;
    }

    if (m_turn == Turn::Player) {
        if (m_movesInPile == 0)
            m_status = QStringLiteral("Your turn (lead)");
        else if (m_haveToMove)
            m_status = QStringLiteral("Your turn (hit %1 or 7)").arg(m_cardToHit);
        else
            m_status = QStringLiteral("Your turn (play or leave)");
    } else {
        if (m_movesInPile == 0)
            m_status = QStringLiteral("AI turn (lead)");
        else if (m_haveToMove)
            m_status = QStringLiteral("AI turn (must hit)");
        else
            m_status = QStringLiteral("AI turn (decision)");
    }
}

bool GameEngine::isGameOverCondition() const
{
    return m_talon.isEmpty() && m_player.isEmpty() && m_cpu.isEmpty() && m_table.isEmpty()
        && !m_pilePending;
}

void GameEngine::finishGame()
{
    // Special rule preserved from your earlier engine:
    // if the last played card of the whole game is a 7, that player loses regardless.
    if (m_lastPlayedWasSeven) {
        const bool lastByPlayer = (m_lastPlayedBy == Turn::Player);
        m_roundResult = lastByPlayer ? QStringLiteral("You lost the round")
                                     : QStringLiteral("You won the round");
        emit roundResultChanged();
        return;
    }

    if (m_playerPoints > m_cpuPoints) {
        m_roundResult = QStringLiteral("You won the round");
    } else if (m_cpuPoints > m_playerPoints) {
        m_roundResult = QStringLiteral("AI won the round");
    } else {
        // 40–40: last pile winner wins
        m_roundResult = (m_lastPileWinner == Winner::Player)
            ? QStringLiteral("You won the round")
            : QStringLiteral("AI won the round");
    }

    emit roundResultChanged();
}
