import Foundation

/// Thin async HTTP client over URLSession.
///
/// Injects the `Authorization: Bearer` header from the token store, encodes/
/// decodes JSON with ISO-8601 dates, and turns non-2xx responses into typed
/// `APIError`s by decoding the server error envelope. A `401` additionally fires
/// `onUnauthorized` (used to log the user out).
@MainActor
final class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenStore: TokenStore
    private let decoder = JSONDecoder.cece
    private let encoder = JSONEncoder.cece

    /// Called when the server responds `401` (e.g. expired token).
    var onUnauthorized: (() -> Void)?

    init(
        baseURL: URL = AppConfig.apiBaseURL,
        session: URLSession = .shared,
        tokenStore: TokenStore,
        onUnauthorized: (() -> Void)? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenStore = tokenStore
        self.onUnauthorized = onUnauthorized
    }

    func get<Response: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> Response {
        try await send(method: "GET", path: path, query: query, body: Optional<EmptyBody>.none)
    }

    func post<Response: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> Response {
        try await send(method: "POST", path: path, query: [], body: body)
    }

    func delete<Response: Decodable>(_ path: String) async throws -> Response {
        try await send(method: "DELETE", path: path, query: [], body: Optional<EmptyBody>.none)
    }

    private struct EmptyBody: Encodable {}

    private func send<Response: Decodable, Body: Encodable>(
        method: String,
        path: String,
        query: [URLQueryItem],
        body: Body?
    ) async throws -> Response {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw APIError.transport("Invalid URL") }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = tokenStore.read() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("No HTTP response")
        }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { onUnauthorized?() }
            throw apiError(from: data, status: http.statusCode)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    private func apiError(from data: Data, status: Int) -> APIError {
        if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
            return APIError(code: envelope.error.code, message: envelope.error.message, status: status)
        }
        return APIError(code: "http_\(status)", message: "Request failed", status: status)
    }
}

/// Wire shape of the server error envelope.
private struct ErrorEnvelope: Decodable {
    struct Body: Decodable {
        let code: String
        let message: String
    }
    let error: Body
}
