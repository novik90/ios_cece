import Foundation

@MainActor
final class MatchDetailViewModel: ObservableObject {
    let match: Match
    private let repository: MatchRepository
    private let tournamentRepository: TournamentRepository

    /// All matches, used for head-to-head counts and player career stats.
    @Published private(set) var allMatches: [Match] = []
    /// All tournaments, used for a player's tournament stats.
    @Published private(set) var allTournaments: [Tournament] = []

    init(match: Match, repository: MatchRepository, tournamentRepository: TournamentRepository) {
        self.match = match
        self.repository = repository
        self.tournamentRepository = tournamentRepository
    }

    func load() {
        allMatches = (try? repository.fetchAll()) ?? []
        allTournaments = (try? tournamentRepository.fetchAll()) ?? []
    }

    // MARK: Result

    var winnerId: UUID? { PlayerStats.winnerId(of: match) }

    var winner: Player? {
        guard let id = winnerId else { return nil }
        return match.player1?.id == id ? match.player1 : match.player2
    }

    var loser: Player? {
        guard let id = winnerId else { return nil }
        return match.player1?.id == id ? match.player2 : match.player1
    }

    func framesWon(by player: Player?) -> Int {
        guard let id = player?.id else { return 0 }
        return match.frames.filter { $0.winnerId == id }.count
    }

    // MARK: Frames

    var frames: [Frame] { match.frames.sorted { $0.frameNumber < $1.frameNumber } }

    // MARK: Times

    var date: Date { match.completedAt ?? match.createdAt }

    var duration: TimeInterval? {
        guard let end = match.completedAt else { return nil }
        return max(0, end.timeIntervalSince(match.createdAt))
    }

    // MARK: Top breaks (more than one ball)

    struct MatchBreak: Identifiable {
        let id: UUID
        let points: Int
        let balls: [SnookerBall]
        let playerName: String
    }

    var topBreaks: [MatchBreak] {
        var collected: [MatchBreak] = []
        for frame in match.frames {
            for brk in frame.breaks where brk.balls.count > 1 {
                let balls = brk.balls.compactMap { SnookerBall(rawValue: $0) }
                collected.append(MatchBreak(
                    id: brk.id,
                    points: brk.points,
                    balls: balls,
                    playerName: playerName(for: brk.playerId)
                ))
            }
        }
        return Array(collected.sorted { $0.points > $1.points }.prefix(5))
    }

    func playerName(for id: UUID) -> String {
        if match.player1?.id == id { return match.player1?.name ?? "—" }
        if match.player2?.id == id { return match.player2?.name ?? "—" }
        return "—"
    }

    // MARK: Head-to-head

    var headToHeadCount: Int {
        guard let a = match.player1?.id, let b = match.player2?.id else { return 0 }
        let pair = Set([a, b])
        return allMatches.filter {
            $0.completedAt != nil &&
            Set([$0.player1?.id, $0.player2?.id].compactMap { $0 }) == pair
        }.count
    }

    // MARK: Player stats (for drilling into a player)

    func stats(for player: Player) -> PlayerStats {
        PlayerStats(player: player, matches: allMatches, tournaments: allTournaments)
    }
}
