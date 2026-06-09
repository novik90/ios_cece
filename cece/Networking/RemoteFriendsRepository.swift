import Foundation

/// Network access to the social graph: friends, requests, user search
/// (contract v3: F1–F6).
@MainActor
final class RemoteFriendsRepository {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    /// Outcome of sending a friend request: a pending outgoing request, or an
    /// instant friendship when a reciprocal request already existed.
    enum SendResult: Equatable {
        case requested(API.FriendRequest)
        case befriended(API.PublicUser)
    }

    /// Search users by `handle` prefix (excludes self).
    func searchUsers(handle: String) async throws -> [API.PublicUser] {
        let response: UsersResponse = try await client.get(
            "/users", query: [URLQueryItem(name: "handle", value: handle)]
        )
        return response.users
    }

    func sendRequest(userId: String) async throws -> SendResult {
        let response: SendResponse = try await client.post("/friends/requests", body: ["userId": userId])
        if response.befriended == true, let friend = response.friend {
            return .befriended(friend)
        }
        return .requested(try response.asFriendRequest())
    }

    func requests(direction: API.FriendRequestDirection) async throws -> [API.FriendRequest] {
        let response: RequestsResponse = try await client.get(
            "/friends/requests", query: [URLQueryItem(name: "direction", value: direction.rawValue)]
        )
        return response.requests
    }

    @discardableResult
    func accept(requestId: String) async throws -> API.PublicUser {
        let response: FriendResponse = try await client.post("/friends/requests/\(requestId)/accept", body: EmptyBody())
        return response.friend
    }

    func decline(requestId: String) async throws {
        let _: OKResponse = try await client.post("/friends/requests/\(requestId)/decline", body: EmptyBody())
    }

    func friends() async throws -> [API.PublicUser] {
        let response: FriendsResponse = try await client.get("/friends")
        return response.friends
    }

    func remove(userId: String) async throws {
        try await client.sendNoContent(method: "DELETE", path: "/friends/\(userId)")
    }
}

private struct EmptyBody: Encodable {}
private struct OKResponse: Decodable { let ok: Bool }
private struct UsersResponse: Decodable { let users: [API.PublicUser] }
private struct RequestsResponse: Decodable { let requests: [API.FriendRequest] }
private struct FriendsResponse: Decodable { let friends: [API.PublicUser] }
private struct FriendResponse: Decodable { let friend: API.PublicUser }

/// `POST /friends/requests` returns either a `FriendRequest` or
/// `{ befriended: true, friend }`.
private struct SendResponse: Decodable {
    let befriended: Bool?
    let friend: API.PublicUser?
    let id: String?
    let user: API.PublicUser?
    let direction: API.FriendRequestDirection?
    let createdAt: Date?

    func asFriendRequest() throws -> API.FriendRequest {
        guard let id, let user, let direction, let createdAt else {
            throw APIError.decoding("Malformed friend request response")
        }
        return API.FriendRequest(id: id, user: user, direction: direction, createdAt: createdAt)
    }
}
