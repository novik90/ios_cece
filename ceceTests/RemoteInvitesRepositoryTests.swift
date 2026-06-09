import Testing
import Foundation
@testable import cece

final class InvitesHTTPStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = InvitesHTTPStub.handler else { return }
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
struct RemoteInvitesRepositoryTests {
    private func makeRepo() -> RemoteInvitesRepository {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [InvitesHTTPStub.self]
        let client = APIClient(
            baseURL: URL(string: "http://test.local/v1")!,
            session: URLSession(configuration: config),
            tokenStore: InMemoryTokenStore("tok")
        )
        return RemoteInvitesRepository(client: client)
    }

    private func resp(_ status: Int, _ json: String, _ req: URLRequest) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: req.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
    }

    private let inviteJSON = #"""
    {"id":"i1","from":{"id":"u1","handle":"a","displayName":"A"},
     "to":{"id":"u2","handle":"b","displayName":"B"},
     "bestOf":5,"selfScoringDisabled":false,"firstBreaker":0,"status":"pending",
     "createdAt":"2026-06-09T00:00:00Z","expiresAt":"2026-06-10T00:00:00Z"}
    """#

    @Test func createDecodesInvite() async throws {
        InvitesHTTPStub.handler = { req in self.resp(201, self.inviteJSON, req) }
        let invite = try await makeRepo().create(userId: "u2", bestOf: 5)
        #expect(invite.id == "i1")
        #expect(invite.status == .pending)
        #expect(invite.matchId == nil)
    }

    @Test func listDecodes() async throws {
        InvitesHTTPStub.handler = { req in self.resp(200, #"{"invites":[\#(self.inviteJSON)]}"#, req) }
        let invites = try await makeRepo().list(direction: .incoming)
        #expect(invites.count == 1)
    }

    @Test func acceptReturnsMatch() async throws {
        InvitesHTTPStub.handler = { req in
            self.resp(201, #"{"id":"m9","participants":[{"kind":"user","userId":"u1","handle":"a","displayName":"A"},{"kind":"user","userId":"u2","handle":"b","displayName":"B"}],"bestOf":5,"status":"scheduled","framesWon":[0,0],"createdAt":"2026-06-09T00:00:00Z","ownerId":"u1"}"#, req)
        }
        let match = try await makeRepo().accept(id: "i1")
        #expect(match.id == "m9")
    }

    @Test func acceptExpiredMapsError() async throws {
        InvitesHTTPStub.handler = { req in self.resp(409, #"{"error":{"code":"invite_expired","message":"old"}}"#, req) }
        await #expect(throws: APIError(code: "invite_expired", message: "old", status: 409)) {
            _ = try await makeRepo().accept(id: "i1")
        }
    }
}
