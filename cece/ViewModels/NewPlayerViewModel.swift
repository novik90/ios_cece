import Foundation

@MainActor
final class NewPlayerViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var errorMessage: String?

    private let repository: PlayerRepository

    init(repository: PlayerRepository) {
        self.repository = repository
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Creates the player. Returns `true` on success so the view can dismiss.
    func save() -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            _ = try repository.create(name: trimmed)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
