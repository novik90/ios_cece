import Testing
import Foundation
@testable import cece

struct ContractModelsTests {
    private let decoder = JSONDecoder.cece

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try decoder.decode(T.self, from: Data(json.utf8))
    }

    @Test func participantUserAndGuestRoundTrip() throws {
        let user = try decode(API.Participant.self,
            #"{"kind":"user","userId":"u1","handle":"ivan","displayName":"Ivan"}"#)
        #expect(user == .user(id: "u1", handle: "ivan", displayName: "Ivan"))
        #expect(user.userId == "u1")
        #expect(user.isGuest == false)

        let guest = try decode(API.Participant.self, #"{"kind":"guest","name":"Гость"}"#)
        #expect(guest == .guest(name: "Гость"))
        #expect(guest.displayName == "Гость")
        #expect(guest.isGuest)

        // encode → decode is stable
        let reEncoded = try JSONEncoder.cece.encode(user)
        #expect(try decoder.decode(API.Participant.self, from: reEncoded) == user)
    }

    @Test func participantRejectsUnknownKind() {
        #expect(throws: (any Error).self) {
            try decode(API.Participant.self, #"{"kind":"alien","name":"x"}"#)
        }
    }

    @Test func decodesMatchSummaryWithDatesAndParticipants() throws {
        let json = #"""
        {
          "id":"m1",
          "participants":[
            {"kind":"user","userId":"u1","handle":"ivan","displayName":"Ivan"},
            {"kind":"guest","name":"Bob"}
          ],
          "bestOf":5,
          "status":"completed",
          "framesWon":[3,1],
          "winner":{"kind":"user","userId":"u1","handle":"ivan","displayName":"Ivan"},
          "createdAt":"2026-06-08T10:00:00.000Z",
          "completedAt":"2026-06-08T10:42:00Z"
        }
        """#
        let summary = try decode(API.MatchSummary.self, json)
        #expect(summary.id == "m1")
        #expect(summary.participants.count == 2)
        #expect(summary.participants[1].isGuest)
        #expect(summary.framesWon == [3, 1])
        #expect(summary.status == .completed)
        #expect(summary.winner?.userId == "u1")
        #expect(summary.completedAt != nil)
    }

    @Test func decodesLiveStateWithFrame() throws {
        let json = #"""
        {
          "matchId":"m1","status":"live","bestOf":5,"framesWon":[1,0],
          "selfScoringDisabled":true,
          "participants":[
            {"kind":"user","userId":"u1","handle":"a","displayName":"A"},
            {"kind":"user","userId":"u2","handle":"b","displayName":"B"}
          ],
          "frame":{
            "frameNumber":2,"breaker":0,"striker":1,"scores":[40,8],
            "redsRemaining":7,"phase":"reds","currentBreak":{"striker":1,"points":8},
            "pointsRemaining":75,"freeBallAvailable":false,"respottedBlack":false,
            "status":"in_progress"
          },
          "highestBreak":[40,8],"version":12
        }
        """#
        let state = try decode(API.MatchLiveState.self, json)
        #expect(state.version == 12)
        #expect(state.selfScoringDisabled)
        #expect(state.frame?.phase == .reds)
        #expect(state.frame?.status == .inProgress)
        #expect(state.frame?.colorOn == nil)
        #expect(state.frame?.currentBreak == API.Break(striker: 1, points: 8))
        #expect(API.Ball.black.points == 7)
    }

    @Test func decodesSocialTypes() throws {
        let req = try decode(API.FriendRequest.self,
            #"{"id":"f1","user":{"id":"u2","handle":"bob","displayName":"Bob"},"direction":"incoming","createdAt":"2026-06-08T00:00:00Z"}"#)
        #expect(req.direction == .incoming)
        #expect(req.user.handle == "bob")

        let invite = try decode(API.MatchInvite.self, #"""
        {"id":"i1","from":{"id":"u1","handle":"a","displayName":"A"},
         "to":{"id":"u2","handle":"b","displayName":"B"},
         "bestOf":7,"selfScoringDisabled":false,"firstBreaker":1,"status":"pending",
         "createdAt":"2026-06-08T00:00:00Z","expiresAt":"2026-06-09T00:00:00Z"}
        """#)
        #expect(invite.status == .pending)
        #expect(invite.firstBreaker == 1)
        #expect(invite.matchId == nil)
    }
}
