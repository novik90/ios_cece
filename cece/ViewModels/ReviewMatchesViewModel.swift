import Foundation

@MainActor
final class ReviewMatchesViewModel: ObservableObject {
    @Published private(set) var matches: [Match] = []
    @Published var errorMessage: String?

    private let repository: MatchRepository

    init(repository: MatchRepository) {
        self.repository = repository
    }

    func load() {
        do {
            matches = try repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { matches[$0] }
        do {
            for match in toDelete {
                try repository.delete(match)
            }
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
