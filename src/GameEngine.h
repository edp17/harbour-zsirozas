#pragma once

#include <QObject>
#include <QVector>
#include <QVariantList>
#include <QTimer>
#include <QString>

class GameEngine : public QObject
{
    Q_OBJECT

    // Existing UI properties used by your QML
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString lastTrick READ lastTrick NOTIFY lastTrickChanged)
    Q_PROPERTY(QString roundResult READ roundResult NOTIFY roundResultChanged)

    Q_PROPERTY(int deckSize READ deckSize NOTIFY stateChanged)
    Q_PROPERTY(int playerScore READ playerScore NOTIFY scoreChanged)
    Q_PROPERTY(int cpuScore READ cpuScore NOTIFY scoreChanged)

    Q_PROPERTY(QVariantList playerHand READ playerHand NOTIFY stateChanged)
    Q_PROPERTY(QVariantList cpuHand READ cpuHand NOTIFY stateChanged)
    Q_PROPERTY(QVariantList tableCards READ tableCards NOTIFY stateChanged)
    Q_PROPERTY(QVariantList playerWonCards READ playerWonCards NOTIFY stateChanged)
    Q_PROPERTY(QVariantList cpuWonCards READ cpuWonCards NOTIFY stateChanged)

    Q_PROPERTY(int aiPlayDelay READ aiPlayDelay WRITE setAiPlayDelay NOTIFY aiPlayDelayChanged)

    // New rule-state properties (0v-style)
    Q_PROPERTY(int cardToHit READ cardToHit NOTIFY stateChanged)
    Q_PROPERTY(bool haveToMove READ haveToMove NOTIFY stateChanged)
    Q_PROPERTY(bool canLeave READ canLeave NOTIFY stateChanged)

    // Kept for compatibility with your current QML button wiring
    // (we’ll map it to canLeave)
    Q_PROPERTY(bool playerCanPass READ canLeave NOTIFY stateChanged)

    Q_PROPERTY(bool playerInputEnabled READ playerInputEnabled NOTIFY stateChanged)
    Q_PROPERTY(bool allowLeave READ allowLeave CONSTANT)

public:
    explicit GameEngine(QObject* parent = nullptr);

    enum class Turn { Player, Cpu };
    Q_ENUM(Turn)

    enum class Winner { Player, Cpu };
    Q_ENUM(Winner)

    struct Card {
        int rank = 0;      // 7..14 (Ace=14)
        int suit = 0;      // 0..3
        int playedBy = -1; // 0 player, 1 cpu, -1 not on table

        QString id() const { return QString::number(suit) + "_" + QString::number(rank); }
        bool isZsir() const { return (rank == 10 || rank == 14); } // 10/A = 10 points each
    };

    // Actions
    Q_INVOKABLE void newGame();
    Q_INVOKABLE void playCard(int handIndex);

    // “Let it go” in UI – in 0v this is “leave / don’t want to move” and awards pile to last hitter.
    Q_INVOKABLE void playerLeave();
    // Backward name kept so you don’t have to change QML call sites if you don’t want to.
    Q_INVOKABLE void playerPass() { playerLeave(); }

    // Read-only getters
    QString status() const { return m_status; }
    QString lastTrick() const { return m_lastTrick; }
    QString roundResult() const { return m_roundResult; }

    int deckSize() const { return m_talon.size(); }
    int playerScore() const { return m_playerPoints; }
    int cpuScore() const { return m_cpuPoints; }

    QVariantList playerHand() const;
    QVariantList cpuHand() const;
    QVariantList tableCards() const;
    QVariantList playerWonCards() const;
    QVariantList cpuWonCards() const;

    int aiPlayDelay() const { return m_aiPlayDelay; }
    void setAiPlayDelay(int ms);

    int cardToHit() const { return m_cardToHit; }
    bool haveToMove() const { return m_haveToMove; }
    bool canLeave() const;

    bool playerInputEnabled() const;

signals:
    void statusChanged();
    void lastTrickChanged();
    void roundResultChanged();
    void scoreChanged();
    void aiPlayDelayChanged();
    void stateChanged();

private:
    // State machine helpers
    void initDeck();
    void refillHands(Winner firstDraws);

    static QVariantList toVariantList(const QVector<Card>& v);

    bool isHitRank(int rank) const;
    bool handHasHitCard(const QVector<Card>& hand) const;

    void applyMove(Turn who, int handIndex);
    void advanceAfterPlay(Turn whoJustPlayed, int playedRank);

    void scheduleRoundWin(Winner winner);
    void resolvePileAfterDelay();
    void commitPile();

    void capturePile(Winner winner);
    void startNextPileWithLeader(Winner leader);

    void maybeScheduleCpuMove();
    int  chooseCpuIndex() const;

    void updateStatusText();

    bool isGameOverCondition() const;
    void finishGame();

private:
    // Cards
    QVector<Card> m_talon;
    QVector<Card> m_player;
    QVector<Card> m_cpu;
    QVector<Card> m_table;
    QVector<Card> m_playerWon;
    QVector<Card> m_cpuWon;

    // Scores
    int m_playerPoints = 0;
    int m_cpuPoints = 0;

    // UI text
    QString m_status;
    QString m_lastTrick;
    QString m_roundResult;

    // Turn
    Turn m_turn = Turn::Player;

    // 0v-style pile state
    int  m_cardToHit = -1;              // rank of first card of pile
    bool m_haveToMove = true;           // forced-hit phase (true) vs starter decision phase (false)
    int  m_movesInPile = 0;             // number of played cards in current pile
    Turn m_roundStarter = Turn::Player; // who led pile
    Winner m_lastHitter = Winner::Player;

    // Pending capture (delay)
    bool   m_pilePending = false;
    Winner m_pendingWinner = Winner::Player;
    bool   m_inputLocked = false;

    // Timers / delays
    QTimer m_aiTimer;
    QTimer m_pileTimer;
    int    m_aiPlayDelay = 1500;
    int    m_pileDelayMs = 400;

    // Endgame special rule preserved from your previous code
    bool m_lastPlayedWasSeven = false;
    Turn m_lastPlayedBy = Turn::Player;

    // For 40–40 tie-breaker
    Winner m_lastPileWinner = Winner::Player;
};
