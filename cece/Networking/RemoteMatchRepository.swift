import Foundation

/// Network access to matches (contract v1: C5–C7). Replaces the local SwiftData
/// match repository for the online flow.
@MainActor
final class RemoteMatchRepository {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    enum Opponent: Equatable {
        case user(id: String)
        case guest(name: String)
    }

    /// Create a match. Opponent by `userId` requires friendship (else
    /// `403 not_friends`); a guest opponent has no restriction.
    func create(
        opponent: Opponent,
        bestOf: Int,
        selfScoringDisabled: Bool = false,
        firstBreaker: Int = 0
    ) async throws -> API.Match {
        let body = CreateMatchBody(
            opponent: .init(
                userId: { if case let .user(id) = opponent { return id } else { return nil } }(),
                guestName: { if case let .guest(name) = opponent { return name } else { return nil } }()
            ),
            bestOf: bestOf,
            selfScoringDisabled: selfScoringDisabled,
            firstBreaker: firstBreaker
        )
        return try await client.post("/matches", body: body)
    }

    /// My matches, newest first. `status` is `all` | `live` | `completed`.
    func list(status: String = "all") async throws -> [API.MatchSummary] {
        let response: MatchListResponse = try await client.get(
            "/matches",
            query: [URLQueryItem(name: "status", value: status)]
        )
        return response.matches
    }

    func get(id: String) async throws -> API.Match {
        try await client.get("/matches/\(id)")
    }
}

private struct CreateMatchBody: Encodable {
    struct Opponent: Encodable {
        let userId: String?
        let guestName: String?
    }
    let opponent: Opponent
    let bestOf: Int
    let selfScoringDisabled: Bool
    let firstBreaker: Int
}

private struct MatchListResponse: Decodable {
    let matches: [API.MatchSummary]
}
