import Foundation

@MainActor
final class ReviewPlayersViewModel: ObservableObject {
    @Published private(set) var players: [Player] = []
    @Published var errorMessage: String?

    private let repository: PlayerRepository

    init(repository: PlayerRepository) {
        self.repository = repository
    }

    func load() {
        do {
            players = try repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { players[$0] }
        do {
            for player in toDelete {
                try repository.delete(player)
            }
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
