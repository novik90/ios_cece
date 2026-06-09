import Testing
import Foundation
@testable import cece

final class MatchHTTPStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = MatchHTTPStub.handler else { return }
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
struct RemoteMatchRepositoryTests {
    private func makeRepo() -> RemoteMatchRepository {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MatchHTTPStub.self]
        let client = APIClient(
            baseURL: URL(string: "http://test.local/v1")!,
            session: URLSession(configuration: config),
            tokenStore: InMemoryTokenStore("tok")
        )
        return RemoteMatchRepository(client: client)
    }

    private func ok(_ status: Int, _ json: String, _ req: URLRequest) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: req.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
    }

    private let matchJSON = #"""
    {"id":"m1","participants":[
        {"kind":"user","userId":"u1","handle":"a","displayName":"A"},
        {"kind":"guest","name":"Bob"}],
     "bestOf":5,"status":"scheduled","framesWon":[0,0],
     "createdAt":"2026-06-08T00:00:00Z","ownerId":"u1"}
    """#

    @Test func createGuestSendsBodyAndDecodesMatch() async throws {
        var sentBody: [String: Any]?
        MatchHTTPStub.handler = { req in
            if let stream = req.httpBodyStream {
                sentBody = Self.readJSON(stream)
            }
            return self.ok(201, self.matchJSON, req)
        }
        let match = try await makeRepo().create(opponent: .guest(name: "Bob"), bestOf: 5)
        #expect(match.id == "m1")
        #expect(match.participants.last?.isGuest == true)
        let opponent = sentBody?["opponent"] as? [String: Any]
        #expect(opponent?["guestName"] as? String == "Bob")
        #expect(opponent?["userId"] == nil)   // omitted for guest
        #expect(sentBody?["bestOf"] as? Int == 5)
    }

    @Test func listDecodesMatches() async throws {
        MatchHTTPStub.handler = { req in
            self.ok(200, #"{"matches":[\#(self.matchJSON)]}"#, req)
        }
        let matches = try await makeRepo().list()
        #expect(matches.count == 1)
        #expect(matches.first?.id == "m1")
    }

    @Test func createNotFriendsMapsError() async throws {
        MatchHTTPStub.handler = { req in
            self.ok(403, #"{"error":{"code":"not_friends","message":"not friends"}}"#, req)
        }
        await #expect(throws: APIError(code: "not_friends", message: "not friends", status: 403)) {
            _ = try await makeRepo().create(opponent: .user(id: "u2"), bestOf: 5)
        }
    }

    private static func readJSON(_ stream: InputStream) -> [String: Any]? {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        var buffer = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
