import Foundation

/// Network access to match invitations (contract v3: I1–I5).
@MainActor
final class RemoteInvitesRepository {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func create(
        userId: String,
        bestOf: Int,
        selfScoringDisabled: Bool = false,
        firstBreaker: Int = 0
    ) async throws -> API.MatchInvite {
        try await client.post("/invites", body: CreateInviteBody(
            userId: userId,
            bestOf: bestOf,
            selfScoringDisabled: selfScoringDisabled,
            firstBreaker: firstBreaker
        ))
    }

    func list(direction: API.FriendRequestDirection) async throws -> [API.MatchInvite] {
        let response: InvitesResponse = try await client.get(
            "/invites", query: [URLQueryItem(name: "direction", value: direction.rawValue)]
        )
        return response.invites
    }

    /// Accepting creates the match (returned).
    func accept(id: String) async throws -> API.Match {
        try await client.post("/invites/\(id)/accept", body: EmptyBody())
    }

    func decline(id: String) async throws {
        let _: OKResponse = try await client.post("/invites/\(id)/decline", body: EmptyBody())
    }

    func cancel(id: String) async throws {
        let _: OKResponse = try await client.post("/invites/\(id)/cancel", body: EmptyBody())
    }
}

private struct CreateInviteBody: Encodable {
    let userId: String
    let bestOf: Int
    let selfScoringDisabled: Bool
    let firstBreaker: Int
}
private struct EmptyBody: Encodable {}
private struct OKResponse: Decodable { let ok: Bool }
private struct InvitesResponse: Decodable { let invites: [API.MatchInvite] }
