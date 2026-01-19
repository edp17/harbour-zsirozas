#include "GameEngine.h"

#include <algorithm>
#include <random>
#include <QTimer>
#include <QVariantMap>
#include <QDebug>

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

int GameEngine::currentTargetRank() const {
    if (table.isEmpty()) return -1;
    if (table.size() == 1) return table.last().rank;
    const Card& prev = table[table.size() - 2];
    const Card& cur  = table.last();
    if (cur.rank == 7) return prev.rank;
    return cur.rank;
}

GameEngine::GameEngine(QObject* parent) : QObject(parent)
{
    m_aiTimer.setSingleShot(true);
    m_pileTimer.setSingleShot(true);

    connect(&m_aiTimer, &QTimer::timeout, this, [this]() {
        if (m_turn != Turn::Cpu) return;
        if (!m_roundResult.isEmpty()) return;
        if (m_pilePending) return;
        if (cpu.isEmpty()) return;

        const int idx = chooseCpuIndex();
        if (idx < 0) return; // only when cpu.isEmpty()
        applyMove(Turn::Cpu, idx);
    });

    connect(&m_pileTimer, &QTimer::timeout, this, [this]() {
        // This must only run if the player still cannot/does not respond
        commitPile();
    });

    newGame();
}

void GameEngine::normalizeTurnIfHandEmpty()
{
    // Only relevant when talon is empty: no more refills will happen.
    if (!talon.isEmpty())
        return;

    if (m_turn == Turn::Player && player.isEmpty() && !cpu.isEmpty()) {
        m_turn = Turn::Cpu;
    } else if (m_turn == Turn::Cpu && cpu.isEmpty() && !player.isEmpty()) {
        m_turn = Turn::Player;
    }
}

bool GameEngine::handHasNonHit(const QVector<Card>& hand) const {
    const int target = responseTargetRank();
    if (target < 0) return false;
    for (const Card& c : hand) {
        const bool isHitCard = (c.rank == target || c.rank == 7);
        if (!isHitCard) return true;
    }
    return false;
}

void GameEngine::cancelPendingActions()
{
    m_aiTimer.stop();
    m_pileTimer.stop();
    m_captureScheduled = false;      // if you still have this flag, keep it in sync
}

void GameEngine::resolvePileAfterDelay()
{
    qDebug() << "[resolvePileAfterDelay] pending=" << m_pilePending
             << "winner=" << (m_pendingWinner == Winner::Player ? "Player" : "CPU")
             << "delay=" << m_pileDelayMs;

    m_aiTimer.stop();            // IMPORTANT: cancel any already scheduled CPU move
    m_pileTimer.stop();
    m_pileTimer.start(m_pileDelayMs);
}

void GameEngine::commitPile()
{
    qDebug() << "[pileTimer timeout] pending=" << m_pilePending << "tableSize=" << table.size();


    if (!m_pilePending)
        return;

    if (table.isEmpty()) {          // stale timer; nothing to do
        m_pilePending = false;
        return;
    }

    // Stop any further scheduled actions.
    cancelPendingActions();

    const Winner winner = m_pendingWinner;

    m_pilePending = false;

    // Capture pile to the recorded winner
    capturePile(winner);

    // Winner leads next
    m_turn = (m_lastPileWinner == Winner::Player) ? Turn::Player : Turn::Cpu;

    // If the intended leader has no cards (endgame), give turn to the other player.
    normalizeTurnIfHandEmpty();

    updatePlayerCanPass();

    if (isGameOverCondition()) {
        finishGame();
        m_inputLocked = false;
        emit stateChanged();
        return;
    }

    m_inputLocked = false;
    emit stateChanged();

    maybeScheduleCpuMove();
}

void GameEngine::maybeScheduleCpuMove()
{
    if (m_turn != Turn::Cpu)
        return;
    if (!m_roundResult.isEmpty())
        return;
    if (m_pilePending)
        return;
    if (cpu.isEmpty())
        return;

    m_aiTimer.stop();
    m_aiTimer.start(m_aiPlayDelay);
}

void GameEngine::setAiPlayDelay(int ms)
{
    if (m_aiPlayDelay == ms)
        return;
    m_aiPlayDelay = ms;
    emit aiPlayDelayChanged();
}

QString GameEngine::status() const { return m_status; }
QString GameEngine::lastTrick() const { return m_lastTrick; }
QString GameEngine::roundResult() const { return m_roundResult; }
int GameEngine::deckSize() const { return talon.size(); }
int GameEngine::playerScore() const { return player_points; }
int GameEngine::cpuScore() const { return cpu_points; }

QVariantList GameEngine::playerHand() const { return toVariantList(player); }
QVariantList GameEngine::cpuHand() const { return toVariantList(cpu); }
QVariantList GameEngine::tableCards() const { return toVariantList(table); }
QVariantList GameEngine::playerWonCards() const { return toVariantList(m_playerWon); }
QVariantList GameEngine::cpuWonCards() const { return toVariantList(m_cpuWon); }

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
    talon = deck;
}

void GameEngine::refillHands(Winner firstDraws)
{
    auto drawOne = [&](QVector<Card>& hand) {
        if (!talon.isEmpty())
            hand.append(talon.takeLast());
    };

    auto fillToFour = [&](QVector<Card>& hand) {
        while (hand.size() < 4 && !talon.isEmpty())
            drawOne(hand);
    };

    if (firstDraws == Winner::Player) {
        fillToFour(player);
        fillToFour(cpu);
    } else {
        fillToFour(cpu);
        fillToFour(player);
    }
}

int GameEngine::responseTargetRank() const
{
    if (table.isEmpty())
        return -1;
    if (table.size() == 1)
        return table.last().rank;

    const Card& prev = table[table.size() - 2];
    const Card& cur  = table.last();

    // If the last card is a 7, it hits the previous card, so the response target is prev.rank
    if (cur.rank == 7)
        return prev.rank;

    return cur.rank;
}

bool GameEngine::handHasLegalHit(const QVector<Card>& hand) const {
    const int target = responseTargetRank();
    if (target < 0) return false;
    for (const Card& c : hand) {
        if (c.rank == target || c.rank == 7) return true;
    }
    return false;
}

void GameEngine::updatePlayerCanPass()
{

    qDebug() << "[updatePlayerCanPass]"
             << "turn=" << (m_turn == Turn::Player ? "Player" : "CPU")
             << "tableSize=" << table.size()
             << "playerHasHit=" << handHasLegalHit(player)
             << "playerHasNonHit=" << handHasNonHit(player)
             << "currentFlag=" << m_playerCanPass;

    bool can = false;

    // Player can pass only when:
    // - It is player's turn
    // - CPU just played a hit (so player is obliged to respond)
    // - Player DOES have a legal hit (so they may choose hit OR "Let it go")
    if (m_turn == Turn::Player && table.size() >= 2) {
        const Card& prev = table[table.size() - 2];
        const Card& cur  = table.last();

        const bool lastByCpu  = (cur.playedBy == 1);
        const bool lastWasHit = (m_lastMoveBy == Turn::Cpu) && m_lastMoveWasHit;

        if (lastWasHit && handHasLegalHit(player))
            can = true;
    }

    if (m_playerCanPass != can) {
        m_playerCanPass = can;
        emit playerCanPassChanged();
    }

}

void GameEngine::maybeAutoPassIfNeeded()
{
    // Your rule-set: if player cannot hit, they must throw one extra card.
    // So do NOT schedule capture here.
    // Just ensure no stale timer is running.
    m_pileTimer.stop();
}

void GameEngine::newGame()
{
    cancelPendingActions();
    m_inputLocked = false;
    m_pilePending = false;
    m_pendingWinner = Winner::Player;
    m_playerWon.clear();
    m_cpuWon.clear();
    table.clear();
    player.clear();
    cpu.clear();
    m_lastTrick.clear();
    m_roundResult.clear();

    player_points = 0;
    cpu_points = 0;

    m_turn = Turn::Player;
    m_lastHitter = Winner::Player;
    m_lastPileWinner = Winner::Player;
    m_playerCanPass = false;

    m_lastPlayedWasSeven = false;
    m_lastPlayedBy = Turn::Player;

    initDeck();

    // Initial deal: 4+4, dealer alternation is irrelevant for single-round engine.
    refillHands(Winner::Player);

    m_status = QStringLiteral("Your turn");
    emit statusChanged();
    emit lastTrickChanged();
    emit roundResultChanged();
    emit scoreChanged();
    emit playerCanPassChanged();
    emit stateChanged();
}

void GameEngine::playCard(int handIndex)
{
    if (!m_roundResult.isEmpty())
        return;

    if (!playerInputEnabled())
        return;

    m_inputLocked = true;
    emit stateChanged();

    applyMove(Turn::Player, handIndex);

    // Release input lock shortly after (debounce)
    QTimer::singleShot(50, this, [this]() {
        // If we entered pile pending resolution, keep locked until commitPile().
        if (!m_pilePending) {
            m_inputLocked = false;
            emit stateChanged();
        }
    });
}

void GameEngine::playerPass()
{
    if (!m_playerCanPass || m_inputLocked)
        return;

    m_aiTimer.stop();
    m_playerCanPass = false;
    emit playerCanPassChanged();

    m_pilePending = true;
    m_pendingWinner = m_lastHitter;   // concede to last hitter
    m_inputLocked = true;

    resolvePileAfterDelay();
    emit stateChanged();
}

void GameEngine::capturePile(Winner winner)
{

    cancelPendingActions();
    m_playerCanPass = false;
    emit playerCanPassChanged();

    int z = 0;
    for (const Card& c : table) {
        if (c.isZsir())
            z += 10;
    }

    if (winner == Winner::Player) {
        player_points += z;
        m_playerWon += table;
        m_lastPileWinner = Winner::Player;
        m_lastTrick = QStringLiteral("You won the trick");
    } else {
        cpu_points += z;
        m_cpuWon += table;
        m_lastPileWinner = Winner::Cpu;
        m_lastTrick = QStringLiteral("AI won the trick");
    }

    table.clear();
    refillHands(winner);

    emit scoreChanged();
    emit lastTrickChanged();
}

void GameEngine::applyMove(Turn who, int handIndex) {
    QVector<Card>& hand = (who == Turn::Player) ? player : cpu;
    if (handIndex < 0 || handIndex >= hand.size()) return;

    // Target to respond to is defined by the table BEFORE this play.
    const int targetBeforePlay = responseTargetRank();

    m_pileTimer.stop();
    m_pilePending = false;
    m_aiTimer.stop();

    Card played = hand.takeAt(handIndex);
    played.playedBy = (who == Turn::Cpu) ? 1 : 0;
    table.append(played);

    qDebug() << "[applyMove]" << (who == Turn::Player ? "Player" : "CPU")
             << "played" << played.rank << "tableSizeNow=" << table.size();

    // First card: establishes leader; no "hit" concept here.
    if (table.size() == 1) {
        m_lastHitter = (who == Turn::Player) ? Winner::Player : Winner::Cpu;
        m_turn = (who == Turn::Player) ? Turn::Cpu : Turn::Player;

        m_lastMoveBy = who;
        m_lastMoveWasHit = false;

        updatePlayerCanPass();
        emit stateChanged();

        if (m_turn == Turn::Cpu)
            maybeScheduleCpuMove();
        return;
    }

    // From the second card onward: a hit matches the previous target, or is a 7.
    const bool hit = (played.rank == targetBeforePlay) || (played.rank == 7);
    m_lastMoveBy = who;
    m_lastMoveWasHit = hit;

    if (hit) {
        m_lastHitter = (who == Turn::Player) ? Winner::Player : Winner::Cpu;
        m_turn = (who == Turn::Player) ? Turn::Cpu : Turn::Player;

        updatePlayerCanPass();
        emit stateChanged();

//        maybeAutoPassIfNeeded();
        if (m_turn == Turn::Cpu) maybeScheduleCpuMove();
        return;
    }

    // Non-hit: pile ends, last hitter wins (your current rule)
    m_pilePending = true;
    m_pendingWinner = m_lastHitter;
    m_inputLocked = true;
    m_playerCanPass = false;
    emit playerCanPassChanged();

    updatePlayerCanPass();
    emit stateChanged();
    resolvePileAfterDelay();
}

int GameEngine::chooseCpuIndex() const
{
    if (cpu.isEmpty())
        return -1;

    // Lead
    if (table.isEmpty())
        return 0;

    const int targetRank = currentTargetRank();

    // If CPU can hit, do it (match or 7)
    for (int i = 0; i < cpu.size(); ++i) {
        const Card& c = cpu[i];
        if (c.rank == targetRank || c.rank == 7)
            return i;
    }

    // Cannot hit -> play a non-hit card if possible, otherwise any card
    for (int i = 0; i < cpu.size(); ++i) {
        const Card& c = cpu[i];
        if (!(c.rank == targetRank || c.rank == 7))
            return i;
    }
    return 0;
}

bool GameEngine::isGameOverCondition() const
{
    return talon.isEmpty() && player.isEmpty() && cpu.isEmpty() && table.isEmpty();
}

void GameEngine::finishGame()
{
    // Special rule: if last played card of the whole game is a 7, that player loses regardless.
    if (m_lastPlayedWasSeven) {
        const bool lastByPlayer = (m_lastPlayedBy == Turn::Player);
        m_roundResult = lastByPlayer ? QStringLiteral("You lost the round")
                                     : QStringLiteral("You won the round");
        emit roundResultChanged();
        return;
    }

    if (player_points > cpu_points) {
        m_roundResult = QStringLiteral("You won the round");
    } else if (cpu_points > player_points) {
        m_roundResult = QStringLiteral("AI won the round");
    } else {
        // 40–40: last pile winner wins
        m_roundResult = (m_lastPileWinner == Winner::Player)
            ? QStringLiteral("You won the round")
            : QStringLiteral("AI won the round");
    }

    emit roundResultChanged();
}


bool GameEngine::playerInputEnabled() const
{
    return m_roundResult.isEmpty()
        && (m_turn == Turn::Player)
        && !m_inputLocked
        && !m_pilePending;
}
