#pragma once

#include "GameCore.h"

#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariantList>

class GameEngine : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString lastTrick READ lastTrick NOTIFY lastTrickChanged)
    Q_PROPERTY(QString roundResult READ roundResult NOTIFY roundResultChanged)
    Q_PROPERTY(int playerCount READ playerCount WRITE setPlayerCount NOTIFY playerCountChanged)
    Q_PROPERTY(int activePlayerCount READ activePlayerCount NOTIFY stateChanged)
    Q_PROPERTY(bool teamGame READ teamGame NOTIFY stateChanged)
    Q_PROPERTY(int turnPlayer READ turnPlayer NOTIFY stateChanged)
    Q_PROPERTY(int deckSize READ deckSize NOTIFY stateChanged)
    Q_PROPERTY(int playerScore READ playerScore NOTIFY scoreChanged)
    Q_PROPERTY(int cpuScore READ cpuScore NOTIFY scoreChanged)
    Q_PROPERTY(int teamScore READ teamScore NOTIFY scoreChanged)
    Q_PROPERTY(int opponentScore READ opponentScore NOTIFY scoreChanged)
    Q_PROPERTY(QVariantList participants READ participants NOTIFY stateChanged)
    Q_PROPERTY(QVariantList playerHand READ playerHand NOTIFY stateChanged)
    Q_PROPERTY(QVariantList cpuHand READ cpuHand NOTIFY stateChanged)
    Q_PROPERTY(QVariantList tableCards READ tableCards NOTIFY stateChanged)
    Q_PROPERTY(QVariantList playerWonCards READ playerWonCards NOTIFY stateChanged)
    Q_PROPERTY(QVariantList cpuWonCards READ cpuWonCards NOTIFY stateChanged)
    Q_PROPERTY(QString playerName READ playerName WRITE setPlayerName NOTIFY namesChanged)
    Q_PROPERTY(QString ai1Name READ ai1Name WRITE setAi1Name NOTIFY namesChanged)
    Q_PROPERTY(QString ai2Name READ ai2Name WRITE setAi2Name NOTIFY namesChanged)
    Q_PROPERTY(QString ai3Name READ ai3Name WRITE setAi3Name NOTIFY namesChanged)
    Q_PROPERTY(int aiPlayDelay READ aiPlayDelay WRITE setAiPlayDelay NOTIFY aiPlayDelayChanged)
    Q_PROPERTY(int aiDifficulty READ ai1Difficulty WRITE setAi1Difficulty NOTIFY difficultiesChanged)
    Q_PROPERTY(int ai1Difficulty READ ai1Difficulty WRITE setAi1Difficulty NOTIFY difficultiesChanged)
    Q_PROPERTY(int ai2Difficulty READ ai2Difficulty WRITE setAi2Difficulty NOTIFY difficultiesChanged)
    Q_PROPERTY(int ai3Difficulty READ ai3Difficulty WRITE setAi3Difficulty NOTIFY difficultiesChanged)
    Q_PROPERTY(bool animationsEnabled READ animationsEnabled WRITE setAnimationsEnabled NOTIFY animationsEnabledChanged)
    Q_PROPERTY(bool paused READ paused WRITE setPaused NOTIFY pausedChanged)
    Q_PROPERTY(int cardToHit READ cardToHit NOTIFY stateChanged)
    Q_PROPERTY(bool haveToMove READ haveToMove NOTIFY stateChanged)
    Q_PROPERTY(bool canLeave READ canLeave NOTIFY stateChanged)
    Q_PROPERTY(bool playerCanPass READ canLeave NOTIFY stateChanged)
    Q_PROPERTY(bool playerInputEnabled READ playerInputEnabled NOTIFY stateChanged)
    Q_PROPERTY(int visualPhase READ visualPhase NOTIFY visualPhaseChanged)

public:
    explicit GameEngine(QObject* parent = nullptr);
    enum class VisualPhase { Idle = 0, CardFlight = 1, CapturePause = 2, PileFlight = 3, Deal = 4 };
    Q_ENUM(VisualPhase)

    Q_INVOKABLE void newGame();
    Q_INVOKABLE void start();
    Q_INVOKABLE void playCard(int handIndex);
    Q_INVOKABLE void playerLeave();
    Q_INVOKABLE void playerPass() { playerLeave(); }
    Q_INVOKABLE bool isPlayerCardPlayable(int handIndex) const;
    Q_INVOKABLE void completeCardAnimation();
    Q_INVOKABLE void completePileAnimation();
    Q_INVOKABLE void completeDealAnimation();

    QString status() const { return m_status; }
    QString lastTrick() const { return m_lastTrick; }
    QString roundResult() const;
    int playerCount() const { return m_configuredPlayerCount; }
    void setPlayerCount(int count);
    int activePlayerCount() const { return m_core.playerCount(); }
    bool teamGame() const { return m_core.isTeamGame(); }
    int turnPlayer() const { return m_core.turn(); }
    int deckSize() const { return static_cast<int>(m_core.talon().size()); }
    int playerScore() const { return m_core.playerPoints(0); }
    int cpuScore() const { return m_core.playerPoints(1); }
    int teamScore() const { return m_core.teamPoints(0); }
    int opponentScore() const { return m_core.teamPoints(1); }

    QVariantList participants() const;
    QVariantList playerHand() const;
    QVariantList cpuHand() const;
    QVariantList tableCards() const;
    QVariantList playerWonCards() const;
    QVariantList cpuWonCards() const;

    QString playerName() const { return m_names[0]; }
    QString ai1Name() const { return m_names[1]; }
    QString ai2Name() const { return m_names[2]; }
    QString ai3Name() const { return m_names[3]; }
    void setPlayerName(const QString& name) { setName(0, name); }
    void setAi1Name(const QString& name) { setName(1, name); }
    void setAi2Name(const QString& name) { setName(2, name); }
    void setAi3Name(const QString& name) { setName(3, name); }
    int aiPlayDelay() const { return m_aiPlayDelay; }
    void setAiPlayDelay(int milliseconds);
    int ai1Difficulty() const { return m_aiDifficulties[1]; }
    int ai2Difficulty() const { return m_aiDifficulties[2]; }
    int ai3Difficulty() const { return m_aiDifficulties[3]; }
    void setAi1Difficulty(int difficulty) { setDifficulty(1, difficulty); }
    void setAi2Difficulty(int difficulty) { setDifficulty(2, difficulty); }
    void setAi3Difficulty(int difficulty) { setDifficulty(3, difficulty); }
    bool animationsEnabled() const { return m_animationsEnabled; }
    void setAnimationsEnabled(bool enabled);
    bool paused() const { return m_paused; }
    void setPaused(bool paused);
    int cardToHit() const { return m_core.cardToHit(); }
    bool haveToMove() const { return m_core.haveToMove(); }
    bool canLeave() const { return m_core.canLeave(0); }
    bool playerInputEnabled() const;
    int visualPhase() const { return static_cast<int>(m_visualPhase); }

signals:
    void statusChanged();
    void lastTrickChanged();
    void roundResultChanged();
    void scoreChanged();
    void playerCountChanged();
    void namesChanged();
    void difficultiesChanged();
    void aiPlayDelayChanged();
    void animationsEnabledChanged();
    void pausedChanged();
    void visualPhaseChanged();
    void stateChanged();
    void cardAnimationRequested(const QString& cardId, int playedBy, int oldHandIndex);
    void pileAnimationRequested(int winnerPlayer);
    void dealAnimationRequested(const QVariantList& dealtCards, int firstPlayer);

private:
    static QString cardId(const Zsirozas::Card& card);
    static QVariantList toVariantList(const std::vector<Zsirozas::Card>& cards);
    static QVariantList initialDealList(const Zsirozas::GameCore& core);
    static QVariantList drawList(const std::vector<Zsirozas::DrawnCard>& cards);
    QString playerDisplayName(int player) const;
    QString teamDisplayName(int team) const;
    int difficultyForPlayer(int player) const;
    void setName(int player, const QString& name);
    void setDifficulty(int player, int difficulty);
    void requestCardAnimation(const QString& cardId, int player, int oldHandIndex);
    void startCapturePause();
    void requestPileAnimation();
    void requestDealAnimation(const QVariantList& cards, int firstPlayer);
    void finishVisualPhase();
    void scheduleAiMove();
    void performAiMove();
    void updateStatusText();
    void setVisualPhase(VisualPhase phase);
    void startWatchdog(int milliseconds);
    void recoverTimedOutVisualPhase();
    void persistGame();
    bool restoreGame();

    Zsirozas::GameCore m_core{2};
    QTimer m_aiTimer;
    QTimer m_capturePauseTimer;
    QTimer m_visualWatchdog;
    QString m_status;
    QString m_lastTrick;
    QString m_names[4] = { QStringLiteral("Player"), QStringLiteral("AI 1"),
                           QStringLiteral("AI 2"), QStringLiteral("AI 3") };
    VisualPhase m_visualPhase = VisualPhase::Idle;
    int m_configuredPlayerCount = 2;
    int m_aiPlayDelay = 650;
    int m_aiDifficulties[4] = { 1, 1, 2, 3 };
    bool m_animationsEnabled = true;
    bool m_paused = false;
    quint64 m_gameGeneration = 0;
};
