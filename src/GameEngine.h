#pragma once
#include <QObject>
#include <QVector>
#include <QString>
#include <QVariantList>
#include <QMetaType>
#include <QTimer>

// Hungarian "Zsírozás" (2-player) simplified engine:
// - 4 cards in hand, draw from talon back to 4 after each pile capture
// - "Hit" with same rank OR any 7
// - If you can hit, you may either hit OR "Let it go" (pass) -> last hitter captures the pile
// - If you cannot hit when it's your obligation to respond, engine auto-passes for you
// - Scoring: 10s and Aces are worth 10 points each (total 80)

struct Card {
    int rank = 0;
    int suit = 0;
    int playedBy = -1; // 0=player, 1=cpu (only meaningful for table layout)
    QString id() const { return QString("%1_%2").arg(suit).arg(rank); }
    bool isZsir() const { return rank == 10 || rank == 14; }
};

Q_DECLARE_METATYPE(Card)

class GameEngine : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString lastTrick READ lastTrick NOTIFY lastTrickChanged)
    Q_PROPERTY(int playerScore READ playerScore NOTIFY scoreChanged)
    Q_PROPERTY(int cpuScore READ cpuScore NOTIFY scoreChanged)
    Q_PROPERTY(QString roundResult READ roundResult NOTIFY roundResultChanged)

    Q_PROPERTY(QVariantList cpuHand READ cpuHand NOTIFY stateChanged)
    Q_PROPERTY(QVariantList playerHand READ playerHand NOTIFY stateChanged)
    Q_PROPERTY(QVariantList tableCards READ tableCards NOTIFY stateChanged)
    Q_PROPERTY(int deckSize READ deckSize NOTIFY stateChanged)

    Q_PROPERTY(QVariantList playerWonCards READ playerWonCards NOTIFY stateChanged)
    Q_PROPERTY(QVariantList cpuWonCards READ cpuWonCards NOTIFY stateChanged)

    Q_PROPERTY(int aiPlayDelay READ aiPlayDelay WRITE setAiPlayDelay NOTIFY aiPlayDelayChanged)

    // True only when it is the player's turn to respond to a CPU hit and the player has a legal hit.
    // In that case the player may either play a hitting card OR tap "Let it go".
    Q_PROPERTY(bool playerCanPass READ playerCanPass NOTIFY playerCanPassChanged)
    Q_PROPERTY(bool playerInputEnabled READ playerInputEnabled NOTIFY stateChanged)
    Q_PROPERTY(int currentTargetRank READ currentTargetRank NOTIFY stateChanged)

public:
    explicit GameEngine(QObject* parent=nullptr);

    // Lists exposed to QML
    QVariantList playerHand() const;
    QVariantList cpuHand() const;
    QVariantList tableCards() const;
    QVariantList playerWonCards() const;
    QVariantList cpuWonCards() const;

    // Values exposed to QML
    QString status() const;
    QString lastTrick() const;
    int playerScore() const;
    int cpuScore() const;
    QString roundResult() const;
    int deckSize() const;

    int aiPlayDelay() const { return m_aiPlayDelay; }
    void setAiPlayDelay(int ms);

    bool playerCanPass() const { return m_playerCanPass; }
    bool playerInputEnabled() const;

    // QML actions
    Q_INVOKABLE void newGame();
    Q_INVOKABLE void playCard(int handIndex);
    Q_INVOKABLE void playerPass();
    int currentTargetRank() const;

signals:
    void stateChanged();
    void statusChanged();
    void lastTrickChanged();
    void scoreChanged();
    void roundResultChanged();
    void aiPlayDelayChanged();
    void playerCanPassChanged();

private:
    enum class Turn { Player, Cpu };
    enum class Winner { Player, Cpu };

    // Core state
    QVector<Card> talon;
    QVector<Card> player;
    QVector<Card> cpu;
    QVector<Card> table;
    QVector<Card> m_playerWon;
    QVector<Card> m_cpuWon;

    Turn   m_turn = Turn::Player;
    Winner m_lastHitter = Winner::Player;     // last successful hitter (also set by leader's first card)
    Winner m_lastPileWinner = Winner::Player; // used for 40-40 tie
    bool   m_playerCanPass = false;
    bool   m_inputLocked = false; // debounce / input lock
    bool   m_pilePending = false;
    Winner m_pendingWinner = Winner::Player;

    // Scoring and messages
    int player_points = 0;
    int cpu_points = 0;
    QString m_status;
    QString m_lastTrick;
    QString m_roundResult;

    // AI timing
    int m_aiPlayDelay = 650;

    // "7 as last card loses" tracking (rule from common Zsírozás rulesets)
    bool   m_lastPlayedWasSeven = false;
    Turn   m_lastPlayedBy = Turn::Player;

    // Helpers
    void initDeck();
    void refillHands(Winner firstDraws);
    static QVariantList toVariantList(const QVector<Card>& v);

    bool handHasLegalHit(const QVector<Card>& hand) const;

    void applyMove(Turn who, int handIndex);
    void resolveAfterMove(bool lastMoveWasHit);
    void capturePile(Winner winner);

    void updatePlayerCanPass();
    void maybeAutoPassIfNeeded();
    void maybeScheduleCpuMove();
    int  chooseCpuIndex() const;

    bool isGameOverCondition() const;
    void finishGame();
    int m_pileDelayMs = 400;
    // pile resolution
    void resolvePileAfterDelay();
    void commitPile();
    bool m_pileResolving = false;

    // Track last move semantics (so UI/logic doesn't infer it from table timing)
    Turn m_lastMoveBy = Turn::Player;
    bool m_lastMoveWasHit = false;

    // Auto-capture scheduling (prevents premature/stale capture)
    bool m_captureScheduled = false;
    Winner m_scheduledWinner = Winner::Player;

    QTimer m_aiTimer;
    QTimer m_pileTimer;
    void cancelPendingActions();

    bool handHasNonHit(const QVector<Card>& hand) const;
    void normalizeTurnIfHandEmpty();
    int responseTargetRank() const;
};
