import Testing
import Foundation
@testable import cece

/// Stubs URLSession at the protocol level so the client can be tested offline.
final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = URLProtocolStub.handler else {
            client?.urlProtocol(self, didFailWithError: APIError.transport("no stub handler"))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite(.serialized)
@MainActor
struct APIClientTests {
    private struct Health: Decodable, Equatable { let status: String; let apiVersion: String }

    private let base = URL(string: "http://test.local/v1")!

    private func makeClient(
        token: String? = nil,
        onUnauthorized: (() -> Void)? = nil
    ) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return APIClient(
            baseURL: base,
            session: URLSession(configuration: config),
            tokenStore: InMemoryTokenStore(token),
            onUnauthorized: onUnauthorized
        )
    }

    private func respond(_ status: Int, _ json: String, for request: URLRequest) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (response, Data(json.utf8))
    }

    @Test func decodesSuccessfulResponse() async throws {
        URLProtocolStub.handler = { req in
            self.respond(200, #"{"status":"ok","apiVersion":"v1"}"#, for: req)
        }
        let client = makeClient()
        let health: Health = try await client.get("/health")
        #expect(health == Health(status: "ok", apiVersion: "v1"))
    }

    @Test func mapsServerErrorEnvelope() async throws {
        URLProtocolStub.handler = { req in
            self.respond(409, #"{"error":{"code":"handle_taken","message":"taken"}}"#, for: req)
        }
        let client = makeClient()
        await #expect(throws: APIError(code: "handle_taken", message: "taken", status: 409)) {
            let _: Health = try await client.get("/me")
        }
    }

    @Test func unauthorizedFiresHookAndThrows() async throws {
        var loggedOut = false
        URLProtocolStub.handler = { req in
            self.respond(401, #"{"error":{"code":"unauthorized","message":"no"}}"#, for: req)
        }
        let client = makeClient(token: "stale", onUnauthorized: { loggedOut = true })

        var caught: APIError?
        do {
            let _: Health = try await client.get("/me")
        } catch let error as APIError {
            caught = error
        }
        #expect(loggedOut)
        #expect(caught?.isUnauthorized == true)
    }

    @Test func injectsAuthorizationHeaderWhenTokenPresent() async throws {
        var seenAuth: String?
        URLProtocolStub.handler = { req in
            seenAuth = req.value(forHTTPHeaderField: "Authorization")
            return self.respond(200, #"{"status":"ok","apiVersion":"v1"}"#, for: req)
        }
        let client = makeClient(token: "abc123")
        let _: Health = try await client.get("/health")
        #expect(seenAuth == "Bearer abc123")
    }

    @Test func transportErrorBecomesAPIError() async throws {
        URLProtocolStub.handler = { _ in throw URLError(.notConnectedToInternet) }
        let client = makeClient()
        var caught: APIError?
        do {
            let _: Health = try await client.get("/health")
        } catch let error as APIError {
            caught = error
        }
        #expect(caught?.status == 0)
        #expect(caught?.code == "network_error")
    }
}
