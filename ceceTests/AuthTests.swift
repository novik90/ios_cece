import Testing
import Foundation
@testable import cece

// MARK: - Validation

struct AuthValidationTests {
    @Test func handleRules() {
        #expect(AuthValidation.isValidHandle("ivan"))
        #expect(AuthValidation.isValidHandle("a_b9"))
        #expect(AuthValidation.isValidHandle("ab") == false)        // too short
        #expect(AuthValidation.isValidHandle("1abc") == false)      // starts with digit
        #expect(AuthValidation.isValidHandle("Ivan") == false)      // uppercase
        #expect(AuthValidation.isValidHandle("a23456789012345678901") == false) // too long
    }

    @Test func passwordAndEmail() {
        #expect(AuthValidation.isValidPassword("12345678"))
        #expect(AuthValidation.isValidPassword("short") == false)
        #expect(AuthValidation.isValidEmail("a@b.com"))
        #expect(AuthValidation.isValidEmail("nope") == false)
    }
}

// MARK: - Session

private final class FakeAuthService: AuthService {
    var registerResult: Result<AuthResult, Error>
    var loginResult: Result<AuthResult, Error>
    var meResult: Result<User, Error>

    init(register: Result<AuthResult, Error> = .failure(APIError.transport("unset")),
         login: Result<AuthResult, Error> = .failure(APIError.transport("unset")),
         me: Result<User, Error> = .failure(APIError.transport("unset"))) {
        registerResult = register
        loginResult = login
        meResult = me
    }

    func register(email: String, password: String, displayName: String, handle: String) async throws -> AuthResult {
        try registerResult.get()
    }
    func login(email: String, password: String) async throws -> AuthResult { try loginResult.get() }
    func me() async throws -> User { try meResult.get() }
}

private func sampleUser(_ handle: String = "ivan") -> User {
    User(id: "u1", handle: handle, displayName: "Ivan", email: "i@x.com", createdAt: Date(timeIntervalSince1970: 0))
}

@MainActor
struct SessionTests {
    @Test func loginSignsInAndStoresToken() async throws {
        let store = InMemoryTokenStore()
        let session = Session(auth: FakeAuthService(login: .success(AuthResult(token: "tok", user: sampleUser()))), tokenStore: store)
        try await session.login(email: "i@x.com", password: "12345678")
        #expect(session.currentUser == sampleUser())
        #expect(store.read() == "tok")
    }

    @Test func logoutClearsState() async throws {
        let store = InMemoryTokenStore("tok")
        let session = Session(auth: FakeAuthService(me: .success(sampleUser())), tokenStore: store)
        await session.restore()
        #expect(session.currentUser != nil)
        session.logout()
        #expect(session.phase == .signedOut)
        #expect(store.read() == nil)
    }

    @Test func restoreWithoutTokenIsSignedOut() async {
        let session = Session(auth: FakeAuthService(), tokenStore: InMemoryTokenStore())
        await session.restore()
        #expect(session.phase == .signedOut)
    }

    @Test func restoreWithValidTokenSignsIn() async {
        let session = Session(auth: FakeAuthService(me: .success(sampleUser())), tokenStore: InMemoryTokenStore("tok"))
        await session.restore()
        #expect(session.currentUser == sampleUser())
    }

    @Test func restoreWithRejectedTokenSignsOutAndClears() async {
        let store = InMemoryTokenStore("stale")
        let session = Session(auth: FakeAuthService(me: .failure(APIError(code: "unauthorized", message: "no", status: 401))), tokenStore: store)
        await session.restore()
        #expect(session.phase == .signedOut)
        #expect(store.read() == nil)
    }
}

// MARK: - RemoteAuthService (dedicated stub to avoid clashing with APIClientTests)

final class AuthHTTPStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = AuthHTTPStub.handler else { return }
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
struct RemoteAuthServiceTests {
    private func makeService() -> RemoteAuthService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthHTTPStub.self]
        let client = APIClient(
            baseURL: URL(string: "http://test.local/v1")!,
            session: URLSession(configuration: config),
            tokenStore: InMemoryTokenStore()
        )
        return RemoteAuthService(client: client)
    }

    @Test func registerDecodesTokenAndUser() async throws {
        AuthHTTPStub.handler = { req in
            let body = #"{"token":"jwt","user":{"id":"u1","handle":"ivan","displayName":"Ivan","email":"i@x.com","createdAt":"2026-06-08T00:00:00.000Z"}}"#
            return (HTTPURLResponse(url: req.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
        }
        let result = try await makeService().register(email: "i@x.com", password: "12345678", displayName: "Ivan", handle: "ivan")
        #expect(result.token == "jwt")
        #expect(result.user.handle == "ivan")
    }

    @Test func registerMapsHandleTaken() async throws {
        AuthHTTPStub.handler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 409, httpVersion: nil, headerFields: nil)!,
             Data(#"{"error":{"code":"handle_taken","message":"taken"}}"#.utf8))
        }
        await #expect(throws: APIError(code: "handle_taken", message: "taken", status: 409)) {
            _ = try await makeService().register(email: "i@x.com", password: "12345678", displayName: "Ivan", handle: "ivan")
        }
    }
}
