import Foundation

/// One break in a player's history, with enough context to display it.
struct BreakStat: Identifiable {
    let id: UUID
    let points: Int
    let balls: [SnookerBall]
    let opponentName: String
    let matchDate: Date
}

/// Aggregated career statistics for a single player, derived from matches.
struct PlayerStats {
    let played: Int
    let wins: Int
    let losses: Int
    let winPercentage: Double
    /// Up to the 10 highest breaks across all of the player's matches.
    let topBreaks: [BreakStat]

    init(player: Player, matches: [Match]) {
        let participated = matches.filter {
            $0.player1?.id == player.id || $0.player2?.id == player.id
        }
        let completed = participated.filter { $0.completedAt != nil }
        let wins = completed.filter { PlayerStats.winnerId(of: $0) == player.id }.count

        self.played = completed.count
        self.wins = wins
        self.losses = completed.count - wins
        self.winPercentage = completed.isEmpty ? 0 : Double(wins) / Double(completed.count) * 100

        var collected: [BreakStat] = []
        for match in participated {
            let opponent = match.player1?.id == player.id ? match.player2 : match.player1
            let opponentName = opponent?.name ?? "—"
            let date = match.completedAt ?? match.createdAt
            for frame in match.frames {
                for brk in frame.breaks where brk.playerId == player.id {
                    let balls = brk.balls.compactMap { SnookerBall(rawValue: $0) }
                    collected.append(BreakStat(
                        id: brk.id,
                        points: brk.points,
                        balls: balls,
                        opponentName: opponentName,
                        matchDate: date
                    ))
                }
            }
        }
        self.topBreaks = Array(collected.sorted { $0.points > $1.points }.prefix(10))
    }

    /// Resolves a match's winner: explicit `winnerId` if set, else by frames won.
    static func winnerId(of match: Match) -> UUID? {
        if let explicit = match.winnerId { return explicit }
        let p1 = match.player1?.id
        let p2 = match.player2?.id
        let w1 = match.frames.filter { $0.winnerId == p1 }.count
        let w2 = match.frames.filter { $0.winnerId == p2 }.count
        if w1 == w2 { return nil }
        return w1 > w2 ? p1 : p2
    }
}

@MainActor
final class PlayersViewModel: ObservableObject {
    @Published private(set) var players: [Player] = []
    @Published var errorMessage: String?

    private let playerRepository: PlayerRepository
    private let matchRepository: MatchRepository
    private var matches: [Match] = []

    init(playerRepository: PlayerRepository, matchRepository: MatchRepository) {
        self.playerRepository = playerRepository
        self.matchRepository = matchRepository
    }

    func load() {
        do {
            players = try playerRepository.fetchAll()
            matches = try matchRepository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stats(for player: Player) -> PlayerStats {
        PlayerStats(player: player, matches: matches)
    }

    func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { players[$0] }
        do {
            for player in toDelete {
                try playerRepository.delete(player)
            }
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
