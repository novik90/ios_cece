import Foundation

@MainActor
final class TournamentsViewModel: ObservableObject {
    @Published private(set) var tournaments: [Tournament] = []
    @Published var errorMessage: String?

    private let repository: TournamentRepository

    init(repository: TournamentRepository) {
        self.repository = repository
    }

    var active: [Tournament] { tournaments.filter { !$0.isCompleted } }
    var completed: [Tournament] { tournaments.filter { $0.isCompleted } }

    func load() {
        do {
            tournaments = try repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ tournament: Tournament) {
        do {
            try repository.delete(tournament)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
