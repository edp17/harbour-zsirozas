#include "GameCore.h"

#include <algorithm>
#include <iomanip>
#include <iterator>
#include <set>
#include <sstream>
#include <utility>

namespace Zsirozas {

namespace {

std::uint32_t randomSeed()
{
    std::random_device device;
    return device();
}

int pointsIn(const std::vector<Card>& cards)
{
    int points = 0;
    for (const Card& card : cards) {
        if (card.isZsir())
            points += 10;
    }
    return points;
}

void writeCards(std::ostream& output, const std::vector<Card>& cards)
{
    output << cards.size();
    for (const Card& card : cards)
        output << ' ' << card.rank << ' ' << card.suit << ' ' << card.playedBy;
    output << '\n';
}

bool readCards(std::istream& input, std::vector<Card>& cards)
{
    unsigned int count = 0;
    if (!(input >> count) || count > 32)
        return false;

    std::vector<Card> parsed;
    parsed.reserve(count);
    for (unsigned int index = 0; index < count; ++index) {
        Card card;
        if (!(input >> card.rank >> card.suit >> card.playedBy))
            return false;
        parsed.push_back(card);
    }
    cards = std::move(parsed);
    return true;
}

std::uint64_t stateChecksum(const std::string& value)
{
    std::uint64_t hash = UINT64_C(14695981039346656037);
    for (const unsigned char byte : value) {
        hash ^= byte;
        hash *= UINT64_C(1099511628211);
    }
    return hash;
}

} // namespace

GameCore::GameCore(int playerCount, std::uint32_t seed)
{
    setPlayerCount(playerCount);
    newGame(seed);
}

std::string GameCore::serializeState() const
{
    std::ostringstream payload;
    payload << m_playerCount << '\n';
    writeCards(payload, m_talon);
    writeCards(payload, m_table);
    for (const std::vector<Card>& playerHand : m_hands)
        writeCards(payload, playerHand);
    for (const std::vector<Card>& playerWon : m_won)
        writeCards(payload, playerWon);
    for (int points : m_points)
        payload << points << ' ';
    payload << '\n';
    payload << m_turn << ' ' << m_cardToHit << ' ' << (m_haveToMove ? 1 : 0) << ' '
            << m_movesInPile << ' ' << m_roundStarter << ' ' << m_lastHitter << ' '
            << (m_pilePending ? 1 : 0) << ' ' << m_pendingWinner << ' '
            << (m_lastPlayedWasSeven ? 1 : 0) << ' ' << m_lastPlayedBy << ' '
            << m_lastPileWinner << ' ' << static_cast<int>(m_roundResult) << '\n';
    payload << m_rng << '\n';

    const std::string body = payload.str();
    std::ostringstream result;
    result << "ZSIROZAS_STATE_V1\n"
           << std::hex << stateChecksum(body) << '\n'
           << body;
    return result.str();
}

bool GameCore::restoreState(const std::string& serialized)
{
    std::istringstream envelope(serialized);
    std::string magic;
    std::string checksumText;
    if (!std::getline(envelope, magic) || magic != "ZSIROZAS_STATE_V1"
        || !std::getline(envelope, checksumText)) {
        return false;
    }

    std::uint64_t expectedChecksum = 0;
    std::istringstream checksumInput(checksumText);
    if (!(checksumInput >> std::hex >> expectedChecksum))
        return false;
    checksumInput >> std::ws;
    if (!checksumInput.eof())
        return false;

    const std::string body((std::istreambuf_iterator<char>(envelope)),
                           std::istreambuf_iterator<char>());
    if (stateChecksum(body) != expectedChecksum)
        return false;

    std::istringstream input(body);
    int playerCount = 0;
    if (!(input >> playerCount) || (playerCount != 2 && playerCount != 4))
        return false;

    GameCore restored(playerCount, 1);
    if (!readCards(input, restored.m_talon) || !readCards(input, restored.m_table))
        return false;

    restored.m_hands.assign(static_cast<std::size_t>(playerCount), {});
    restored.m_won.assign(static_cast<std::size_t>(playerCount), {});
    restored.m_points.assign(static_cast<std::size_t>(playerCount), 0);
    for (std::vector<Card>& playerHand : restored.m_hands) {
        if (!readCards(input, playerHand))
            return false;
    }
    for (std::vector<Card>& playerWon : restored.m_won) {
        if (!readCards(input, playerWon))
            return false;
    }
    for (int& points : restored.m_points) {
        if (!(input >> points))
            return false;
    }

    int haveToMove = 0;
    int pilePending = 0;
    int lastPlayedWasSeven = 0;
    int roundResult = 0;
    if (!(input >> restored.m_turn >> restored.m_cardToHit >> haveToMove
          >> restored.m_movesInPile >> restored.m_roundStarter >> restored.m_lastHitter
          >> pilePending >> restored.m_pendingWinner >> lastPlayedWasSeven
          >> restored.m_lastPlayedBy >> restored.m_lastPileWinner >> roundResult)
        || (haveToMove != 0 && haveToMove != 1)
        || (pilePending != 0 && pilePending != 1)
        || (lastPlayedWasSeven != 0 && lastPlayedWasSeven != 1)
        || roundResult < static_cast<int>(RoundResult::None)
        || roundResult > static_cast<int>(RoundResult::Team1Won)) {
        return false;
    }
    restored.m_haveToMove = haveToMove != 0;
    restored.m_pilePending = pilePending != 0;
    restored.m_lastPlayedWasSeven = lastPlayedWasSeven != 0;
    restored.m_roundResult = static_cast<RoundResult>(roundResult);

    if (!(input >> restored.m_rng))
        return false;
    input >> std::ws;
    if (!input.eof())
        return false;

    std::string error;
    if (!restored.validate(&error))
        return false;
    *this = std::move(restored);
    return true;
}

void GameCore::setPlayerCount(int playerCount)
{
    m_playerCount = playerCount == 4 ? 4 : 2;
}

bool GameCore::validPlayer(int player) const
{
    return player >= 0 && player < m_playerCount;
}

int GameCore::nextPlayer(int player) const
{
    return (player + 1) % m_playerCount;
}

int GameCore::nextPlayerWithCards(int player) const
{
    int candidate = player;
    for (int offset = 0; offset < m_playerCount; ++offset) {
        if (!m_hands[static_cast<std::size_t>(candidate)].empty())
            return candidate;
        candidate = nextPlayer(candidate);
    }
    return player;
}

const std::vector<Card>& GameCore::hand(int player) const
{
    static const std::vector<Card> empty;
    return validPlayer(player) ? m_hands[static_cast<std::size_t>(player)] : empty;
}

const std::vector<Card>& GameCore::wonCards(int player) const
{
    static const std::vector<Card> empty;
    return validPlayer(player) ? m_won[static_cast<std::size_t>(player)] : empty;
}

int GameCore::playerPoints(int player) const
{
    return validPlayer(player) ? m_points[static_cast<std::size_t>(player)] : 0;
}

int GameCore::teamPoints(int team) const
{
    int points = 0;
    for (int player = 0; player < m_playerCount; ++player) {
        if (teamForPlayer(player) == team)
            points += playerPoints(player);
    }
    return points;
}

int GameCore::winningTeam() const
{
    switch (m_roundResult) {
    case RoundResult::Team0Won:
        return 0;
    case RoundResult::Team1Won:
        return 1;
    case RoundResult::None:
        return -1;
    }
    return -1;
}

void GameCore::newGame(std::uint32_t seed)
{
    m_rng.seed(seed == 0 ? randomSeed() : seed);

    m_talon.clear();
    m_table.clear();
    m_hands.assign(static_cast<std::size_t>(m_playerCount), {});
    m_won.assign(static_cast<std::size_t>(m_playerCount), {});
    m_points.assign(static_cast<std::size_t>(m_playerCount), 0);

    m_talon.reserve(32);
    for (int suit = 0; suit < 4; ++suit) {
        for (int rank = 7; rank <= 14; ++rank)
            m_talon.push_back(Card{rank, suit, -1});
    }
    std::shuffle(m_talon.begin(), m_talon.end(), m_rng);

    m_turn = 0;
    m_cardToHit = -1;
    m_haveToMove = true;
    m_movesInPile = 0;
    m_roundStarter = 0;
    m_lastHitter = 0;
    m_pilePending = false;
    m_pendingWinner = 0;
    m_lastPlayedWasSeven = false;
    m_lastPlayedBy = 0;
    m_lastPileWinner = 0;
    m_roundResult = RoundResult::None;

    refillHands(0);
}

std::vector<DrawnCard> GameCore::refillHands(int firstPlayer)
{
    std::vector<DrawnCard> drawn;
    if (!validPlayer(firstPlayer))
        return drawn;

    while (!m_talon.empty()) {
        bool drew = false;
        for (int offset = 0; offset < m_playerCount && !m_talon.empty(); ++offset) {
            const int player = (firstPlayer + offset) % m_playerCount;
            std::vector<Card>& playerHand = m_hands[static_cast<std::size_t>(player)];
            if (playerHand.size() >= 4)
                continue;

            Card card = m_talon.back();
            m_talon.pop_back();
            card.playedBy = -1;
            playerHand.push_back(card);
            drawn.push_back(DrawnCard{
                player, card, static_cast<int>(playerHand.size() - 1)
            });
            drew = true;
        }
        if (!drew)
            break;
    }
    return drawn;
}

bool GameCore::isHitRank(int rank) const
{
    return m_cardToHit >= 0 && (rank == m_cardToHit || rank == 7);
}

bool GameCore::handHasHitCard(int player) const
{
    if (!validPlayer(player) || m_cardToHit < 0)
        return false;
    const std::vector<Card>& playerHand = hand(player);
    return std::any_of(playerHand.begin(), playerHand.end(), [this](const Card& card) {
        return isHitRank(card.rank);
    });
}

bool GameCore::humanInputEnabled() const
{
    return m_roundResult == RoundResult::None
        && !m_pilePending
        && m_turn == 0
        && !hand(0).empty();
}

bool GameCore::canLeave(int player) const
{
    if (!validPlayer(player)
        || m_roundResult != RoundResult::None
        || m_pilePending
        || m_turn != player) {
        return false;
    }
    if (m_movesInPile < m_playerCount
        || m_haveToMove
        || m_roundStarter != player
        || teamForPlayer(m_lastHitter) == teamForPlayer(player)) {
        return false;
    }
    return handHasHitCard(player);
}

std::vector<int> GameCore::legalMoves(int player) const
{
    std::vector<int> legal;
    if (!validPlayer(player)
        || m_roundResult != RoundResult::None
        || m_pilePending
        || m_turn != player) {
        return legal;
    }

    const std::vector<Card>& playerHand = hand(player);
    if (playerHand.empty())
        return legal;

    const bool hitOnly = canLeave(player);
    for (std::size_t index = 0; index < playerHand.size(); ++index) {
        if (!hitOnly || isHitRank(playerHand[index].rank))
            legal.push_back(static_cast<int>(index));
    }
    return legal;
}

bool GameCore::playCard(int player, int handIndex)
{
    const std::vector<int> legal = legalMoves(player);
    if (std::find(legal.begin(), legal.end(), handIndex) == legal.end())
        return false;

    std::vector<Card>& playerHand = m_hands[static_cast<std::size_t>(player)];
    Card played = playerHand[static_cast<std::size_t>(handIndex)];
    playerHand.erase(playerHand.begin() + handIndex);
    played.playedBy = player;
    m_table.push_back(played);

    m_lastPlayedWasSeven = played.rank == 7;
    m_lastPlayedBy = player;
    advanceAfterPlay(player, played.rank);
    return true;
}

bool GameCore::leave(int player)
{
    if (!canLeave(player))
        return false;
    schedulePileWin(m_lastHitter);
    return true;
}

void GameCore::advanceAfterPlay(int player, int rank)
{
    ++m_movesInPile;

    if (m_movesInPile == 1) {
        m_cardToHit = rank;
        m_roundStarter = player;
        m_lastHitter = player;
        m_haveToMove = true;
        m_turn = nextPlayerWithCards(nextPlayer(player));
        if (m_turn == player)
            schedulePileWin(m_lastHitter);
        return;
    }

    if (isHitRank(rank))
        m_lastHitter = player;

    m_turn = nextPlayerWithCards(nextPlayer(player));
    if (m_turn != m_roundStarter) {
        m_haveToMove = true;
        return;
    }

    // A continuation decision happens only after every active participant has
    // contributed once.  The leader can continue only while the opposing team
    // controls the multiple trick and the leader can supply a hit.
    m_haveToMove = false;
    if (teamForPlayer(m_lastHitter) == teamForPlayer(m_roundStarter)
        || !handHasHitCard(m_roundStarter)) {
        schedulePileWin(m_lastHitter);
    }
}

void GameCore::schedulePileWin(int player)
{
    if (!validPlayer(player) || m_table.empty() || m_pilePending)
        return;
    m_pendingWinner = player;
    m_pilePending = true;
}

CaptureResult GameCore::commitPile()
{
    CaptureResult result;
    result.winnerPlayer = m_pendingWinner;
    result.winnerTeam = teamForPlayer(m_pendingWinner);
    if (!m_pilePending || m_table.empty())
        return result;

    const int points = pilePoints();
    m_points[static_cast<std::size_t>(m_pendingWinner)] += points;
    std::vector<Card>& winnerPile = m_won[static_cast<std::size_t>(m_pendingWinner)];
    winnerPile.insert(winnerPile.end(), m_table.begin(), m_table.end());
    m_lastPileWinner = m_pendingWinner;
    m_table.clear();
    m_pilePending = false;

    result.drawn = refillHands(m_pendingWinner);
    startNextPile(m_pendingWinner);

    bool handsEmpty = true;
    for (const std::vector<Card>& playerHand : m_hands)
        handsEmpty = handsEmpty && playerHand.empty();
    if (m_talon.empty() && handsEmpty && m_table.empty()) {
        finishGame();
        result.gameOver = true;
    }
    return result;
}

void GameCore::startNextPile(int leader)
{
    m_cardToHit = -1;
    m_movesInPile = 0;
    m_haveToMove = true;
    m_turn = nextPlayerWithCards(leader);
    m_roundStarter = m_turn;
    m_lastHitter = leader;
}

void GameCore::finishGame()
{
    int winnerTeam = -1;
    if (m_lastPlayedWasSeven) {
        winnerTeam = opposingTeam(teamForPlayer(m_lastPlayedBy));
    } else {
        const int team0 = teamPoints(0);
        const int team1 = teamPoints(1);
        if (team0 > team1)
            winnerTeam = 0;
        else if (team1 > team0)
            winnerTeam = 1;
        else
            winnerTeam = teamForPlayer(m_lastPileWinner);
    }
    m_roundResult = winnerTeam == 0 ? RoundResult::Team0Won : RoundResult::Team1Won;
}

int GameCore::pilePoints() const
{
    return pointsIn(m_table);
}

double GameCore::estimatedCounterProbability(int player, int targetRank) const
{
    bool known[4][15] = {};
    auto mark = [&known](const std::vector<Card>& cards) {
        for (const Card& card : cards)
            known[card.suit][card.rank] = true;
    };
    mark(hand(player));
    mark(m_table);
    for (const std::vector<Card>& pile : m_won)
        mark(pile);

    int unknownCards = 0;
    int unknownCounters = 0;
    for (int suit = 0; suit < 4; ++suit) {
        for (int rank = 7; rank <= 14; ++rank) {
            if (known[suit][rank])
                continue;
            ++unknownCards;
            if (rank == targetRank || rank == 7)
                ++unknownCounters;
        }
    }

    int unseenHandCards = 0;
    for (int other = 0; other < m_playerCount; ++other) {
        if (other != player)
            unseenHandCards += static_cast<int>(hand(other).size());
    }
    if (unknownCards == 0 || unknownCounters == 0 || unseenHandCards == 0)
        return 0.0;

    double noCounter = 1.0;
    for (int draw = 0; draw < unseenHandCards && draw < unknownCards; ++draw) {
        const int remainingNonCounters = unknownCards - unknownCounters - draw;
        const int remainingCards = unknownCards - draw;
        if (remainingNonCounters <= 0) {
            noCounter = 0.0;
            break;
        }
        noCounter *= static_cast<double>(remainingNonCounters)
            / static_cast<double>(remainingCards);
    }
    return 1.0 - noCounter;
}

int GameCore::scoreAiMove(int player, int handIndex, AiDifficulty difficulty) const
{
    if (!validPlayer(player)
        || handIndex < 0
        || static_cast<std::size_t>(handIndex) >= hand(player).size()) {
        return -1000000;
    }

    const Card& card = hand(player)[static_cast<std::size_t>(handIndex)];
    const bool opening = m_movesInPile == 0;
    const bool hit = !opening && isHitRank(card.rank);
    const bool ownTeamControls = !opening
        && teamForPlayer(m_lastHitter) == teamForPlayer(player);
    const bool strategic = difficulty == AiDifficulty::Hard
        || difficulty == AiDifficulty::Expert;
    int score = 0;

    if (opening) {
        score += 18 - card.rank;
        if (card.rank == 7)
            score -= strategic ? 38 : 28;
        if (card.isZsir())
            score -= strategic ? 30 : 22;

        const int copies = static_cast<int>(std::count_if(
            hand(player).begin(), hand(player).end(), [&card](const Card& other) {
                return other.rank == card.rank;
            }));
        if (copies >= 2)
            score += strategic ? 18 : 4;
        if (difficulty == AiDifficulty::Expert) {
            const double risk = estimatedCounterProbability(player, card.rank);
            score += static_cast<int>((1.0 - risk) * 70.0);
        }
        return score;
    }

    if (hit) {
        score += 110 + pilePoints() * (strategic ? 6 : 4);
        if (card.rank == m_cardToHit)
            score += strategic ? 38 : 25;
        if (card.rank == 7)
            score -= strategic ? 32 : 22;
        if (card.isZsir())
            score -= ownTeamControls ? 25 : 10;
        if (isTeamGame() && ownTeamControls)
            score -= strategic ? 125 : 55;
        if (difficulty == AiDifficulty::Expert) {
            const double risk = estimatedCounterProbability(player, m_cardToHit);
            // A likely counter is a reason to conserve an expensive hit, but
            // not to concede routinely: making an opponent spend a counter
            // still has tactical value.
            score -= static_cast<int>(risk * (pilePoints() + 8) * 0.75);
        }
    } else {
        score += 18 - card.rank;
        if (card.rank == 7)
            score -= 100;
        if (card.isZsir()) {
            if (isTeamGame() && ownTeamControls)
                score += strategic ? 72 : 24;
            else
                score -= strategic ? 55 : 38;
        }
    }
    return score;
}

bool GameCore::shouldAiLeave(int player, AiDifficulty difficulty, int bestMove)
{
    if (!canLeave(player) || bestMove < 0)
        return false;

    const Card& card = hand(player)[static_cast<std::size_t>(bestMove)];
    const int value = pilePoints();
    switch (difficulty) {
    case AiDifficulty::Easy:
        return m_rng() % 3 == 0;
    case AiDifficulty::Normal:
        return value == 0 && (card.rank == 7 || card.isZsir());
    case AiDifficulty::Hard:
        return value == 0 && (card.rank == 7 || card.isZsir());
    case AiDifficulty::Expert: {
        const double risk = estimatedCounterProbability(player, m_cardToHit);
        if (value == 0)
            return card.rank == 7 || card.isZsir();
        return value == 10 && card.rank == 7 && risk > 0.78;
    }
    }
    return false;
}

int GameCore::chooseRandom(const std::vector<int>& moves)
{
    if (moves.empty())
        return -1;
    std::uniform_int_distribution<std::size_t> distribution(0, moves.size() - 1);
    return moves[distribution(m_rng)];
}

int GameCore::chooseBest(int player,
                         const std::vector<int>& moves,
                         AiDifficulty difficulty)
{
    if (moves.empty())
        return -1;

    int bestScore = -1000000;
    std::vector<int> best;
    for (int move : moves) {
        const int score = scoreAiMove(player, move, difficulty);
        if (score > bestScore) {
            bestScore = score;
            best.assign(1, move);
        } else if (score == bestScore) {
            best.push_back(move);
        }
    }
    return chooseRandom(best);
}

AiAction GameCore::chooseAiAction(int player, AiDifficulty difficulty)
{
    if (!validPlayer(player))
        return AiAction{};

    const std::vector<int> moves = legalMoves(player);
    if (moves.empty())
        return AiAction{};

    int move = -1;
    if (difficulty == AiDifficulty::Easy) {
        move = chooseRandom(moves);
    } else if ((difficulty == AiDifficulty::Normal && m_rng() % 5 == 0)
               || (difficulty == AiDifficulty::Hard && m_rng() % 20 == 0)) {
        // Normal and Hard leave progressively smaller human-like margins for
        // error. Expert always uses its best public-information evaluation.
        move = chooseRandom(moves);
    } else {
        move = chooseBest(player, moves, difficulty);
    }
    if (shouldAiLeave(player, difficulty, move))
        return AiAction{AiActionType::Leave, -1};
    return AiAction{AiActionType::Play, move};
}

bool GameCore::validate(std::string* error) const
{
    auto fail = [error](const std::string& message) {
        if (error)
            *error = message;
        return false;
    };

    if (m_playerCount != 2 && m_playerCount != 4)
        return fail("player count is neither two nor four");
    if (m_hands.size() != static_cast<std::size_t>(m_playerCount)
        || m_won.size() != static_cast<std::size_t>(m_playerCount)
        || m_points.size() != static_cast<std::size_t>(m_playerCount)) {
        return fail("per-player storage size differs from player count");
    }
    if (!validPlayer(m_turn)
        || !validPlayer(m_roundStarter)
        || !validPlayer(m_lastHitter)
        || !validPlayer(m_pendingWinner)
        || !validPlayer(m_lastPileWinner)) {
        return fail("indexed player state is out of range");
    }

    std::set<int> cards;
    std::size_t total = 0;
    auto inspect = [&cards, &total, &fail](const std::vector<Card>& group) {
        total += group.size();
        for (const Card& card : group) {
            if (card.rank < 7 || card.rank > 14 || card.suit < 0 || card.suit > 3)
                return fail("card outside the 32-card Hungarian deck");
            if (!cards.insert(card.key()).second)
                return fail("duplicate card in game state");
        }
        return true;
    };

    if (!inspect(m_talon) || !inspect(m_table))
        return false;
    for (int player = 0; player < m_playerCount; ++player) {
        if (!inspect(hand(player)) || !inspect(wonCards(player)))
            return false;
        if (hand(player).size() > 4)
            return fail("hand size exceeds four");
        if (playerPoints(player) != pointsIn(wonCards(player)))
            return fail("score does not match captured zsir cards");
    }
    if (total != 32)
        return fail("card conservation failed");
    if (m_table.size() != static_cast<std::size_t>(m_movesInPile))
        return fail("table size differs from movesInPile");
    if (m_table.empty()) {
        if (m_cardToHit != -1 || m_movesInPile != 0 || m_pilePending)
            return fail("empty table retains active pile state");
    } else if (m_cardToHit != m_table.front().rank) {
        return fail("cardToHit differs from the first table card");
    }
    if (m_pilePending && m_table.empty())
        return fail("pending pile has no cards");
    if (m_roundResult != RoundResult::None) {
        bool handsEmpty = true;
        for (const std::vector<Card>& playerHand : m_hands)
            handsEmpty = handsEmpty && playerHand.empty();
        if (!(m_talon.empty() && handsEmpty && m_table.empty()))
            return fail("round result set before all cards were consumed");
    }
    return true;
}

} // namespace Zsirozas
