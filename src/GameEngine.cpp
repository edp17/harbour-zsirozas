#include "GameEngine.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QSettings>
#include <QStandardPaths>
#include <QVariantMap>
#include <algorithm>

using Zsirozas::AiAction;
using Zsirozas::AiActionType;
using Zsirozas::AiDifficulty;
using Zsirozas::RoundResult;

namespace {

const QString autosaveKey = QStringLiteral("game/autosave-v1");

QString autosaveSettingsPath()
{
    const QString directory = QStandardPaths::writableLocation(
        QStandardPaths::AppConfigLocation);
    QDir().mkpath(directory);
    return directory + QLatin1Char('/')
        + QCoreApplication::applicationName() + QStringLiteral(".conf");
}

} // namespace

GameEngine::GameEngine(QObject* parent) : QObject(parent)
{
    m_aiTimer.setSingleShot(true);
    m_capturePauseTimer.setSingleShot(true);
    m_visualWatchdog.setSingleShot(true);
    connect(&m_aiTimer, &QTimer::timeout, this, &GameEngine::performAiMove);
    connect(&m_capturePauseTimer, &QTimer::timeout, this, &GameEngine::requestPileAnimation);
    connect(&m_visualWatchdog, &QTimer::timeout, this, &GameEngine::recoverTimedOutVisualPhase);
    updateStatusText();
}

QString GameEngine::cardId(const Zsirozas::Card& card)
{
    return QString::number(card.suit) + QLatin1Char('_') + QString::number(card.rank);
}

QVariantList GameEngine::toVariantList(const std::vector<Zsirozas::Card>& cards)
{
    QVariantList result;
    result.reserve(static_cast<int>(cards.size()));
    for (const Zsirozas::Card& card : cards) {
        QVariantMap item;
        item[QStringLiteral("rank")] = card.rank;
        item[QStringLiteral("suit")] = card.suit;
        item[QStringLiteral("id")] = cardId(card);
        item[QStringLiteral("isZsir")] = card.isZsir();
        item[QStringLiteral("playedBy")] = card.playedBy;
        result.append(item);
    }
    return result;
}

QVariantList GameEngine::initialDealList(const Zsirozas::GameCore& core)
{
    QVariantList result;
    int order = 0;
    for (int handIndex = 0; handIndex < 4; ++handIndex) {
        for (int player = 0; player < core.playerCount(); ++player) {
            if (handIndex >= static_cast<int>(core.hand(player).size()))
                continue;
            QVariantMap item;
            item[QStringLiteral("player")] = player;
            item[QStringLiteral("id")] = cardId(core.hand(player)[static_cast<std::size_t>(handIndex)]);
            item[QStringLiteral("handIndex")] = handIndex;
            item[QStringLiteral("order")] = order++;
            result.append(item);
        }
    }
    return result;
}

QVariantList GameEngine::drawList(const std::vector<Zsirozas::DrawnCard>& cards)
{
    QVariantList result;
    result.reserve(static_cast<int>(cards.size()));
    int order = 0;
    for (const Zsirozas::DrawnCard& drawn : cards) {
        QVariantMap item;
        item[QStringLiteral("player")] = drawn.player;
        item[QStringLiteral("id")] = cardId(drawn.card);
        item[QStringLiteral("handIndex")] = drawn.handIndex;
        item[QStringLiteral("order")] = order++;
        result.append(item);
    }
    return result;
}

QVariantList GameEngine::participants() const
{
    QVariantList result;
    for (int player = 0; player < m_core.playerCount(); ++player) {
        QVariantMap item;
        item[QStringLiteral("index")] = player;
        item[QStringLiteral("name")] = playerDisplayName(player);
        item[QStringLiteral("isHuman")] = player == 0;
        item[QStringLiteral("team")] = m_core.teamForPlayer(player);
        item[QStringLiteral("hand")] = toVariantList(m_core.hand(player));
        item[QStringLiteral("handCount")] = static_cast<int>(m_core.hand(player).size());
        item[QStringLiteral("wonCards")] = toVariantList(m_core.wonCards(player));
        item[QStringLiteral("wonCount")] = static_cast<int>(m_core.wonCards(player).size());
        item[QStringLiteral("score")] = m_core.playerPoints(player);
        result.append(item);
    }
    return result;
}

QVariantList GameEngine::playerHand() const { return toVariantList(m_core.hand(0)); }
QVariantList GameEngine::cpuHand() const { return toVariantList(m_core.hand(1)); }
QVariantList GameEngine::tableCards() const { return toVariantList(m_core.table()); }
QVariantList GameEngine::playerWonCards() const { return toVariantList(m_core.wonCards(0)); }
QVariantList GameEngine::cpuWonCards() const { return toVariantList(m_core.wonCards(1)); }

QString GameEngine::playerDisplayName(int player) const
{
    const QString name = player >= 0 && player < 4 ? m_names[player].trimmed() : QString();
    if (!name.isEmpty())
        return name;
    return player == 0 ? QStringLiteral("Player") : QStringLiteral("AI %1").arg(player);
}

QString GameEngine::teamDisplayName(int team) const
{
    if (!m_core.isTeamGame())
        return playerDisplayName(team);
    return playerDisplayName(team) + QStringLiteral(" & ") + playerDisplayName(team + 2);
}

QString GameEngine::roundResult() const
{
    switch (m_core.roundResult()) {
    case RoundResult::Team0Won: return tr("%1 won the round").arg(teamDisplayName(0));
    case RoundResult::Team1Won: return tr("%1 won the round").arg(teamDisplayName(1));
    case RoundResult::None: return QString();
    }
    return QString();
}

void GameEngine::setPlayerCount(int count)
{
    count = count == 4 ? 4 : 2;
    if (m_configuredPlayerCount == count)
        return;
    m_configuredPlayerCount = count;
    emit playerCountChanged();
}

void GameEngine::setName(int player, const QString& name)
{
    if (player < 0 || player >= 4 || m_names[player] == name)
        return;
    m_names[player] = name;
    updateStatusText();
    emit namesChanged();
    emit roundResultChanged();
    emit stateChanged();
}

void GameEngine::setDifficulty(int player, int difficulty)
{
    if (player < 1 || player >= 4)
        return;
    difficulty = std::max(static_cast<int>(AiDifficulty::Easy),
                          std::min(static_cast<int>(AiDifficulty::Expert), difficulty));
    if (m_aiDifficulties[player] == difficulty)
        return;
    m_aiDifficulties[player] = difficulty;
    emit difficultiesChanged();
}

int GameEngine::difficultyForPlayer(int player) const
{
    return player >= 1 && player < 4 ? m_aiDifficulties[player]
                                     : static_cast<int>(AiDifficulty::Normal);
}

void GameEngine::setAiPlayDelay(int milliseconds)
{
    milliseconds = std::max(0, milliseconds);
    if (m_aiPlayDelay == milliseconds)
        return;
    m_aiPlayDelay = milliseconds;
    emit aiPlayDelayChanged();
    if (m_aiTimer.isActive())
        scheduleAiMove();
}

void GameEngine::setAnimationsEnabled(bool enabled)
{
    if (m_animationsEnabled == enabled)
        return;
    m_animationsEnabled = enabled;
    emit animationsEnabledChanged();
    if (enabled)
        return;
    switch (m_visualPhase) {
    case VisualPhase::CardFlight: completeCardAnimation(); break;
    case VisualPhase::CapturePause: m_capturePauseTimer.stop(); requestPileAnimation(); break;
    case VisualPhase::PileFlight: completePileAnimation(); break;
    case VisualPhase::Deal: completeDealAnimation(); break;
    case VisualPhase::Idle: break;
    }
}

void GameEngine::setPaused(bool paused)
{
    if (m_paused == paused)
        return;
    m_paused = paused;
    if (paused)
        m_aiTimer.stop();
    else
        scheduleAiMove();
    emit pausedChanged();
}

bool GameEngine::playerInputEnabled() const
{
    return m_visualPhase == VisualPhase::Idle && m_core.humanInputEnabled();
}

bool GameEngine::isPlayerCardPlayable(int handIndex) const
{
    if (!playerInputEnabled())
        return false;
    const std::vector<int> moves = m_core.legalMoves(0);
    return std::find(moves.begin(), moves.end(), handIndex) != moves.end();
}

void GameEngine::newGame()
{
    ++m_gameGeneration;
    m_aiTimer.stop();
    m_capturePauseTimer.stop();
    m_visualWatchdog.stop();
    m_core.setPlayerCount(m_configuredPlayerCount);
    m_core.newGame();
    persistGame();
    m_lastTrick.clear();
    emit lastTrickChanged();
    emit scoreChanged();
    emit roundResultChanged();
    const QVariantList dealt = initialDealList(m_core);
    setVisualPhase(VisualPhase::Deal);
    emit stateChanged();
    const quint64 generation = m_gameGeneration;
    QTimer::singleShot(0, this, [this, dealt, generation]() {
        if (generation == m_gameGeneration && m_visualPhase == VisualPhase::Deal)
            requestDealAnimation(dealt, 0);
    });
}

void GameEngine::start()
{
    ++m_gameGeneration;
    m_aiTimer.stop();
    m_capturePauseTimer.stop();
    m_visualWatchdog.stop();
    if (!restoreGame()) {
        newGame();
        return;
    }

    m_lastTrick.clear();
    emit lastTrickChanged();
    emit scoreChanged();
    emit roundResultChanged();
    setVisualPhase(VisualPhase::Idle);
    emit stateChanged();
    if (m_core.pilePending())
        startCapturePause();
    else
        scheduleAiMove();
}

void GameEngine::playCard(int handIndex)
{
    if (!isPlayerCardPlayable(handIndex))
        return;
    const Zsirozas::Card card = m_core.hand(0)[static_cast<std::size_t>(handIndex)];
    if (m_core.playCard(0, handIndex)) {
        persistGame();
        requestCardAnimation(cardId(card), 0, handIndex);
    }
}

void GameEngine::playerLeave()
{
    if (m_visualPhase == VisualPhase::Idle && m_core.leave(0)) {
        persistGame();
        startCapturePause();
    }
}

void GameEngine::requestCardAnimation(const QString& id, int player, int oldHandIndex)
{
    m_aiTimer.stop();
    setVisualPhase(VisualPhase::CardFlight);
    emit stateChanged();
    emit cardAnimationRequested(id, player, oldHandIndex);
    if (m_animationsEnabled)
        startWatchdog(5000);
    else
        QTimer::singleShot(0, this, &GameEngine::completeCardAnimation);
}

void GameEngine::completeCardAnimation()
{
    if (m_visualPhase != VisualPhase::CardFlight)
        return;
    m_visualWatchdog.stop();
    if (m_core.pilePending()) {
        startCapturePause();
        return;
    }
    finishVisualPhase();
}

void GameEngine::startCapturePause()
{
    setVisualPhase(VisualPhase::CapturePause);
    emit stateChanged();
    m_capturePauseTimer.start(m_animationsEnabled ? 320 : 0);
}

void GameEngine::requestPileAnimation()
{
    if (m_visualPhase != VisualPhase::CapturePause || !m_core.pilePending())
        return;
    setVisualPhase(VisualPhase::PileFlight);
    emit stateChanged();
    emit pileAnimationRequested(m_core.pendingWinner());
    if (m_animationsEnabled)
        startWatchdog(8000);
    else
        QTimer::singleShot(0, this, &GameEngine::completePileAnimation);
}

void GameEngine::completePileAnimation()
{
    if (m_visualPhase != VisualPhase::PileFlight)
        return;
    m_visualWatchdog.stop();
    const Zsirozas::CaptureResult capture = m_core.commitPile();
    persistGame();
    m_lastTrick = tr("%1 won the pile").arg(playerDisplayName(capture.winnerPlayer));
    emit lastTrickChanged();
    emit scoreChanged();
    emit roundResultChanged();
    const QVariantList dealt = drawList(capture.drawn);
    if (!dealt.isEmpty() && !capture.gameOver) {
        setVisualPhase(VisualPhase::Deal);
        emit stateChanged();
        requestDealAnimation(dealt, capture.winnerPlayer);
        return;
    }
    finishVisualPhase();
}

void GameEngine::requestDealAnimation(const QVariantList& cards, int firstPlayer)
{
    if (m_visualPhase != VisualPhase::Deal)
        return;
    emit dealAnimationRequested(cards, firstPlayer);
    if (m_animationsEnabled)
        startWatchdog(10000);
    else
        QTimer::singleShot(0, this, &GameEngine::completeDealAnimation);
}

void GameEngine::completeDealAnimation()
{
    if (m_visualPhase != VisualPhase::Deal)
        return;
    m_visualWatchdog.stop();
    finishVisualPhase();
}

void GameEngine::finishVisualPhase()
{
    setVisualPhase(VisualPhase::Idle);
    emit stateChanged();
    scheduleAiMove();
}

void GameEngine::scheduleAiMove()
{
    m_aiTimer.stop();
    if (m_paused || m_visualPhase != VisualPhase::Idle || m_core.roundResult() != RoundResult::None
        || m_core.pilePending() || m_core.turn() == 0)
        return;
    m_aiTimer.start(m_aiPlayDelay);
}

void GameEngine::performAiMove()
{
    const int player = m_core.turn();
    if (m_paused || m_visualPhase != VisualPhase::Idle || m_core.roundResult() != RoundResult::None
        || player <= 0 || player >= m_core.playerCount())
        return;
    const AiAction action = m_core.chooseAiAction(
        player, static_cast<AiDifficulty>(difficultyForPlayer(player)));
    if (action.type == AiActionType::Leave) {
        if (m_core.leave(player)) {
            persistGame();
            startCapturePause();
        }
        return;
    }
    if (action.type != AiActionType::Play || action.handIndex < 0
        || action.handIndex >= static_cast<int>(m_core.hand(player).size())) {
        qWarning() << "No legal AI action for player" << player;
        return;
    }
    const Zsirozas::Card card = m_core.hand(player)[static_cast<std::size_t>(action.handIndex)];
    if (m_core.playCard(player, action.handIndex)) {
        persistGame();
        requestCardAnimation(cardId(card), player, action.handIndex);
    }
}

void GameEngine::setVisualPhase(VisualPhase phase)
{
    if (m_visualPhase == phase) {
        updateStatusText();
        return;
    }
    m_visualPhase = phase;
    updateStatusText();
    emit visualPhaseChanged();
}

void GameEngine::updateStatusText()
{
    QString next;
    if (m_core.roundResult() != RoundResult::None) {
        next.clear();
    } else if (m_visualPhase == VisualPhase::Deal) {
        next = tr("Dealing...");
    } else if (m_visualPhase == VisualPhase::CapturePause || m_visualPhase == VisualPhase::PileFlight) {
        next = tr("Resolving...");
    } else if (m_visualPhase == VisualPhase::CardFlight) {
        next = tr("Playing...");
    } else if (m_core.turn() == 0) {
        if (m_core.movesInPile() == 0)
            next = tr("%1's turn (lead)").arg(playerDisplayName(0));
        else if (m_core.canLeave(0))
            next = tr("Your turn (hit or let it go)");
        else if (m_core.handHasHitCard(0))
            next = tr("Your turn (hit or discard)");
        else
            next = tr("Your turn (discard)");
    } else {
        const QString name = playerDisplayName(m_core.turn());
        if (m_core.movesInPile() == 0)
            next = tr("%1 is leading...").arg(name);
        else if (m_core.canLeave(m_core.turn()))
            next = tr("%1 is deciding...").arg(name);
        else
            next = tr("%1 is playing...").arg(name);
    }
    if (m_status == next)
        return;
    m_status = next;
    emit statusChanged();
}

void GameEngine::startWatchdog(int milliseconds) { m_visualWatchdog.start(milliseconds); }

void GameEngine::persistGame()
{
    QSettings settings(autosaveSettingsPath(), QSettings::NativeFormat);
    settings.setValue(autosaveKey, QByteArray::fromStdString(m_core.serializeState()));
    settings.sync();
}

bool GameEngine::restoreGame()
{
    QSettings settings(autosaveSettingsPath(), QSettings::NativeFormat);
    const QByteArray saved = settings.value(autosaveKey).toByteArray();
    if (!saved.isEmpty() && m_core.restoreState(saved.toStdString()))
        return true;
    if (!saved.isEmpty()) {
        settings.remove(autosaveKey);
        settings.sync();
    }
    return false;
}

void GameEngine::recoverTimedOutVisualPhase()
{
    qWarning() << "Visual phase watchdog recovered phase" << visualPhase();
    switch (m_visualPhase) {
    case VisualPhase::CardFlight: completeCardAnimation(); break;
    case VisualPhase::CapturePause: requestPileAnimation(); break;
    case VisualPhase::PileFlight: completePileAnimation(); break;
    case VisualPhase::Deal: completeDealAnimation(); break;
    case VisualPhase::Idle: break;
    }
}
