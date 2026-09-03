#pragma once

#include <cstdint>
#include <random>
#include <string>
#include <vector>

namespace Zsirozas {

enum class AiDifficulty { Easy = 0, Normal = 1, Hard = 2, Expert = 3 };
enum class RoundResult { None, Team0Won, Team1Won };
enum class AiActionType { Play, Leave, None };

struct Card {
    int rank = 0;      // 7..14 (Ace = 14)
    int suit = 0;      // 0..3
    int playedBy = -1; // indexed player, -1 while in a hand or talon

    bool isZsir() const { return rank == 10 || rank == 14; }
    int key() const { return suit * 100 + rank; }
};

struct AiAction {
    AiActionType type = AiActionType::None;
    int handIndex = -1;
};

struct DrawnCard {
    int player = 0;
    Card card;
    int handIndex = -1;
};

struct CaptureResult {
    int winnerPlayer = 0;
    int winnerTeam = 0;
    std::vector<DrawnCard> drawn;
    bool gameOver = false;
};

class GameCore
{
public:
    explicit GameCore(int playerCount = 2, std::uint32_t seed = 0);

    void setPlayerCount(int playerCount);
    void newGame(std::uint32_t seed = 0);

    bool playCard(int player, int handIndex);
    bool leave(int player);
    CaptureResult commitPile();

    std::vector<int> legalMoves(int player) const;
    AiAction chooseAiAction(int player, AiDifficulty difficulty);

    bool canLeave(int player) const;
    bool humanInputEnabled() const;
    bool handHasHitCard(int player) const;
    bool isHitRank(int rank) const;
    bool validate(std::string* error = nullptr) const;
    std::string serializeState() const;
    bool restoreState(const std::string& serialized);

    int playerCount() const { return m_playerCount; }
    bool isTeamGame() const { return m_playerCount == 4; }
    int teamForPlayer(int player) const { return isTeamGame() ? player % 2 : player; }
    int opposingTeam(int team) const { return team == 0 ? 1 : 0; }

    const std::vector<Card>& talon() const { return m_talon; }
    const std::vector<Card>& hand(int player) const;
    const std::vector<Card>& table() const { return m_table; }
    const std::vector<Card>& wonCards(int player) const;

    int playerPoints(int player) const;
    int teamPoints(int team) const;
    int cardToHit() const { return m_cardToHit; }
    int movesInPile() const { return m_movesInPile; }
    bool haveToMove() const { return m_haveToMove; }
    int turn() const { return m_turn; }
    int roundStarter() const { return m_roundStarter; }
    int lastHitter() const { return m_lastHitter; }
    int pendingWinner() const { return m_pendingWinner; }
    int lastPileWinner() const { return m_lastPileWinner; }
    bool pilePending() const { return m_pilePending; }
    RoundResult roundResult() const { return m_roundResult; }
    int winningTeam() const;

private:
    friend struct GameCoreTestAccess;

    bool validPlayer(int player) const;
    int nextPlayer(int player) const;
    int nextPlayerWithCards(int player) const;
    std::vector<DrawnCard> refillHands(int firstPlayer);
    void advanceAfterPlay(int player, int rank);
    void schedulePileWin(int player);
    void startNextPile(int leader);
    void finishGame();

    int pilePoints() const;
    int scoreAiMove(int player, int handIndex, AiDifficulty difficulty) const;
    double estimatedCounterProbability(int player, int targetRank) const;
    bool shouldAiLeave(int player, AiDifficulty difficulty, int bestMove);
    int chooseRandom(const std::vector<int>& moves);
    int chooseBest(int player, const std::vector<int>& moves, AiDifficulty difficulty);

private:
    int m_playerCount = 2;
    std::vector<Card> m_talon;
    std::vector<std::vector<Card>> m_hands;
    std::vector<Card> m_table;
    std::vector<std::vector<Card>> m_won;
    std::vector<int> m_points;

    int m_turn = 0;
    int m_cardToHit = -1;
    bool m_haveToMove = true;
    int m_movesInPile = 0;
    int m_roundStarter = 0;
    int m_lastHitter = 0;

    bool m_pilePending = false;
    int m_pendingWinner = 0;

    bool m_lastPlayedWasSeven = false;
    int m_lastPlayedBy = 0;
    int m_lastPileWinner = 0;
    RoundResult m_roundResult = RoundResult::None;

    std::mt19937 m_rng;
};

} // namespace Zsirozas
