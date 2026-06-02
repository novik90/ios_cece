import Foundation

@MainActor
final class ReviewMatchesViewModel: ObservableObject {
    @Published private(set) var matches: [Match] = []
    @Published var errorMessage: String?

    private let repository: MatchRepository

    init(repository: MatchRepository) {
        self.repository = repository
    }

    /// Completed matches played inside a tournament.
    var tournamentMatches: [Match] { matches.filter(\.isTournamentMatch) }
    /// Completed matches played outside any tournament.
    var otherMatches: [Match] { matches.filter { !$0.isTournamentMatch } }

    func load() {
        do {
            // Statistics shows played (completed) matches only.
            matches = try repository.fetchAll().filter { $0.completedAt != nil }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ matchesToDelete: [Match]) {
        do {
            for match in matchesToDelete {
                try repository.delete(match)
            }
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
