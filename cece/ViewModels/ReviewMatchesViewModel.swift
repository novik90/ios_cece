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
            // Statistics shows played (completed) matches only.
            matches = try repository.fetchAll().filter { $0.completedAt != nil }
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
