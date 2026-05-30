import Foundation

@MainActor
final class NewMatchViewModel: ObservableObject {
    @Published private(set) var players: [Player] = []
    @Published var player1: Player?
    @Published var player2: Player?
    /// Best-of options offered in the UI.
    let frameOptions = [1, 3, 5, 7, 9, 11, 15, 19, 35]
    @Published var totalFrames: Int = 5
    @Published var errorMessage: String?

    private let playerRepository: PlayerRepository
    private let matchRepository: MatchRepository

    init(playerRepository: PlayerRepository, matchRepository: MatchRepository) {
        self.playerRepository = playerRepository
        self.matchRepository = matchRepository
    }

    func loadPlayers() {
        do {
            players = try playerRepository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var canCreate: Bool {
        guard let p1 = player1, let p2 = player2 else { return false }
        return p1.id != p2.id
    }

    /// Creates the match and returns it on success.
    func createMatch() -> Match? {
        guard let p1 = player1, let p2 = player2, canCreate else { return nil }
        do {
            return try matchRepository.create(player1: p1, player2: p2, totalFrames: totalFrames)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
