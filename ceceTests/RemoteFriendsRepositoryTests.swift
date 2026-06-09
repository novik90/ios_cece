import Testing
import Foundation
@testable import cece

final class FriendsHTTPStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = FriendsHTTPStub.handler else { return }
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
struct RemoteFriendsRepositoryTests {
    private func makeRepo() -> RemoteFriendsRepository {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FriendsHTTPStub.self]
        let client = APIClient(
            baseURL: URL(string: "http://test.local/v1")!,
            session: URLSession(configuration: config),
            tokenStore: InMemoryTokenStore("tok")
        )
        return RemoteFriendsRepository(client: client)
    }

    private func resp(_ status: Int, _ json: String, _ req: URLRequest) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: req.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
    }

    @Test func sendRequestReturnsPending() async throws {
        FriendsHTTPStub.handler = { req in
            self.resp(201, #"{"id":"r1","user":{"id":"u2","handle":"bob","displayName":"Bob"},"direction":"outgoing","createdAt":"2026-06-09T00:00:00Z"}"#, req)
        }
        let result = try await makeRepo().sendRequest(userId: "u2")
        guard case let .requested(request) = result else { Issue.record("expected requested"); return }
        #expect(request.user.handle == "bob")
        #expect(request.direction == .outgoing)
    }

    @Test func sendRequestReturnsBefriendedOnReciprocal() async throws {
        FriendsHTTPStub.handler = { req in
            self.resp(200, #"{"befriended":true,"friend":{"id":"u2","handle":"bob","displayName":"Bob"}}"#, req)
        }
        let result = try await makeRepo().sendRequest(userId: "u2")
        #expect(result == .befriended(API.PublicUser(id: "u2", handle: "bob", displayName: "Bob")))
    }

    @Test func friendsAndRequestsDecode() async throws {
        FriendsHTTPStub.handler = { req in
            self.resp(200, #"{"friends":[{"id":"u2","handle":"bob","displayName":"Bob"}]}"#, req)
        }
        let friends = try await makeRepo().friends()
        #expect(friends.map(\.handle) == ["bob"])
    }

    @Test func acceptReturnsFriend() async throws {
        FriendsHTTPStub.handler = { req in
            self.resp(200, #"{"friend":{"id":"u2","handle":"bob","displayName":"Bob"}}"#, req)
        }
        let friend = try await makeRepo().accept(requestId: "r1")
        #expect(friend.id == "u2")
    }

    @Test func removeSucceedsOn204() async throws {
        FriendsHTTPStub.handler = { req in (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data()) }
        try await makeRepo().remove(userId: "u2")   // no throw
    }

    @Test func removeMapsNotFriends() async throws {
        FriendsHTTPStub.handler = { req in
            self.resp(404, #"{"error":{"code":"not_friends","message":"no"}}"#, req)
        }
        await #expect(throws: APIError(code: "not_friends", message: "no", status: 404)) {
            try await makeRepo().remove(userId: "u2")
        }
    }
}
