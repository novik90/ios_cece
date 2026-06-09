import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published private(set) var friends: [API.PublicUser] = []
    @Published private(set) var incoming: [API.FriendRequest] = []
    @Published private(set) var outgoing: [API.FriendRequest] = []
    @Published var errorMessage: String?

    private let repo: RemoteFriendsRepository

    init(repo: RemoteFriendsRepository) {
        self.repo = repo
    }

    func loadAll() async {
        do {
            async let friends = repo.friends()
            async let incoming = repo.requests(direction: .incoming)
            async let outgoing = repo.requests(direction: .outgoing)
            self.friends = try await friends
            self.incoming = try await incoming
            self.outgoing = try await outgoing
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func accept(_ request: API.FriendRequest) async {
        await run { try await self.repo.accept(requestId: request.id) }
    }

    func decline(_ request: API.FriendRequest) async {
        await run { try await self.repo.decline(requestId: request.id) }
    }

    func remove(_ user: API.PublicUser) async {
        await run { try await self.repo.remove(userId: user.id) }
    }

    func search(handle: String) async -> [API.PublicUser] {
        do {
            return try await repo.searchUsers(handle: handle)
        } catch {
            errorMessage = Self.message(for: error)
            return []
        }
    }

    func send(userId: String) async -> RemoteFriendsRepository.SendResult? {
        do {
            let result = try await repo.sendRequest(userId: userId)
            await loadAll()
            return result
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
        case "already_friends": return "You're already friends."
        case "friend_request_exists": return "A request is already pending."
        case "request_not_pending": return "That request was already handled."
        case "not_friends": return "You're not friends."
        case "user_not_found": return "User not found."
        case "network_error": return "No connection. Check your internet and try again."
        default: return api.message
        }
    }
}
