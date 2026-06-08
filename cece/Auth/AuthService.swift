import Foundation

/// Result of a successful auth call: a token and the account it belongs to.
struct AuthResult: Equatable {
    let token: String
    let user: User
}

/// Auth operations against the backend (contract v1: C1–C3).
protocol AuthService {
    func register(email: String, password: String, displayName: String, handle: String) async throws -> AuthResult
    func login(email: String, password: String) async throws -> AuthResult
    func me() async throws -> User
}

@MainActor
final class RemoteAuthService: AuthService {
    private let client: APIClient

    init(client: APIClient) { self.client = client }

    private struct AuthResponse: Decodable {
        let token: String
        let user: User
    }
    private struct RegisterBody: Encodable {
        let email: String
        let password: String
        let displayName: String
        let handle: String
    }
    private struct LoginBody: Encodable {
        let email: String
        let password: String
    }

    func register(email: String, password: String, displayName: String, handle: String) async throws -> AuthResult {
        let response: AuthResponse = try await client.post(
            "/auth/register",
            body: RegisterBody(email: email, password: password, displayName: displayName, handle: handle)
        )
        return AuthResult(token: response.token, user: response.user)
    }

    func login(email: String, password: String) async throws -> AuthResult {
        let response: AuthResponse = try await client.post(
            "/auth/login",
            body: LoginBody(email: email, password: password)
        )
        return AuthResult(token: response.token, user: response.user)
    }

    func me() async throws -> User {
        try await client.get("/me")
    }
}
