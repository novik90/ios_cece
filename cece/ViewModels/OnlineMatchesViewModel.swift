import Foundation

@MainActor
final class OnlineMatchesViewModel: ObservableObject {
    @Published private(set) var matches: [API.MatchSummary] = []
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false

    private let repo: RemoteMatchRepository

    init(repo: RemoteMatchRepository) {
        self.repo = repo
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            matches = try await repo.list()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Creates a guest match (opponent by `userId` requires friendship — block G).
    func createGuestMatch(name: String, bestOf: Int) async -> API.Match? {
        do {
            return try await repo.create(opponent: .guest(name: name), bestOf: bestOf)
        } catch {
            errorMessage = Self.message(for: error)
            return nil
        }
    }

    static func message(for error: Error) -> String {
        guard let api = error as? APIError else { return "Something went wrong. Please try again." }
        switch api.code {
        case "not_friends": return "You can only start a direct match with a friend. Send an invite instead."
        case "validation_error": return "Please check the form and try again."
        case "network_error": return "No connection. Check your internet and try again."
        default: return api.message
        }
    }
}
