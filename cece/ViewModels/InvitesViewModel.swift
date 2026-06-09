import Foundation

@MainActor
final class InvitesViewModel: ObservableObject {
    @Published private(set) var incoming: [API.MatchInvite] = []
    @Published private(set) var outgoing: [API.MatchInvite] = []
    @Published var errorMessage: String?

    private let repo: RemoteInvitesRepository

    init(repo: RemoteInvitesRepository) {
        self.repo = repo
    }

    func loadAll() async {
        do {
            async let incoming = repo.list(direction: .incoming)
            async let outgoing = repo.list(direction: .outgoing)
            self.incoming = try await incoming
            self.outgoing = try await outgoing
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Accepting creates the match (returned for navigation).
    func accept(_ invite: API.MatchInvite) async -> API.Match? {
        do {
            let match = try await repo.accept(id: invite.id)
            await loadAll()
            return match
        } catch {
            errorMessage = Self.message(for: error)
            return nil
        }
    }

    func decline(_ invite: API.MatchInvite) async { await run { try await self.repo.decline(id: invite.id) } }
    func cancel(_ invite: API.MatchInvite) async { await run { try await self.repo.cancel(id: invite.id) } }

    @discardableResult
    func create(userId: String, bestOf: Int, selfScoringDisabled: Bool = false, firstBreaker: Int = 0) async -> API.MatchInvite? {
        do {
            let invite = try await repo.create(userId: userId, bestOf: bestOf, selfScoringDisabled: selfScoringDisabled, firstBreaker: firstBreaker)
            await loadAll()
            return invite
        } catch {
            errorMessage = Self.message(for: error)
            return nil
        }
    }

    private func run(_ action: () async throws -> Void) async {
        do {
            try await action()
            await loadAll()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    static func message(for error: Error) -> String {
        guard let api = error as? APIError else { return "Something went wrong. Please try again." }
        switch api.code {
        case "invite_expired": return "This invite has expired."
        case "invite_not_pending": return "This invite was already handled."
        case "forbidden": return "You can't do that."
        case "user_not_found": return "User not found."
        case "validation_error": return "Please check the form and try again."
        case "network_error": return "No connection. Check your internet and try again."
        default: return api.message
        }
    }
}
