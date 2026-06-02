import Foundation

/// Drives launching (or resuming) the match behind a ready bracket slot.
@MainActor
final class TournamentMatchSetupViewModel: ObservableObject {
    let node: TournamentMatch

    /// Best-of options offered in the UI (mirrors `NewMatchViewModel`).
    let frameOptions = [1, 3, 5, 7, 9, 11, 15, 19, 35]
    @Published var totalFrames: Int = 5

    @Published private(set) var player1: Player?
    @Published private(set) var player2: Player?
    @Published var errorMessage: String?

    private let playerRepository: PlayerRepository
    private let matchRepository: MatchRepository
    private let tournamentRepository: TournamentRepository

    init(node: TournamentMatch, dependencies: Dependencies) {
        self.node = node
        self.playerRepository = dependencies.playerRepository
        self.matchRepository = dependencies.matchRepository
        self.tournamentRepository = dependencies.tournamentRepository
    }

    /// The match already started for this slot, if any (for resume).
    var existingMatch: Match? { node.match }

    /// A new match can be started only when both slots are filled and none
    /// exists yet.
    var canStart: Bool {
        existingMatch == nil && player1 != nil && player2 != nil
    }

    func loadPlayers() {
        do {
            let byId = Dictionary(uniqueKeysWithValues: try playerRepository.fetchAll().map { ($0.id, $0) })
            player1 = node.slot1PlayerId.flatMap { byId[$0] }
            player2 = node.slot2PlayerId.flatMap { byId[$0] }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Starts (or returns the in-progress) match for this slot. The match is
    /// created via the shared `MatchRepository` and linked to the bracket node so
    /// completing it advances the tournament (T4).
    func startMatch() -> Match? {
        if let existing = existingMatch { return existing }
        guard let p1 = player1, let p2 = player2 else { return nil }
        do {
            let match = try matchRepository.create(player1: p1, player2: p2, totalFrames: totalFrames)
            node.match = match
            try tournamentRepository.save()
            return match
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
