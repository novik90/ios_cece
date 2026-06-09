import Testing
import Foundation
@testable import cece

@MainActor
struct MatchScoringViewModelTests {
    private func make(myUserId: String?, selfScoringDisabled: Bool = false)
        -> (MatchScoringViewModel, FakeMatchChannel) {
        let channel = FakeMatchChannel()
        let vm = MatchScoringViewModel(channel: channel, myUserId: myUserId)
        vm.start()
        channel.emit(.sample(selfScoringDisabled: selfScoringDisabled))
        return (vm, channel)
    }

    @Test func emittedStatePopulatesViewModel() {
        let (vm, _) = make(myUserId: "u1")
        #expect(vm.state?.matchId == "m1")
        #expect(vm.connection == .connected)
        #expect(vm.frame?.frameNumber == 2)
    }

    @Test func mySlotAndStrikerDerivation() {
        let (alice, _) = make(myUserId: "u1")   // striker in the sample
        #expect(alice.mySlot == 0)
        #expect(alice.iAmStriker == true)

        let (bob, _) = make(myUserId: "u2")
        #expect(bob.mySlot == 1)
        #expect(bob.iAmStriker == false)

        let (spectator, _) = make(myUserId: "zzz")
        #expect(spectator.mySlot == nil)
    }

    @Test func normalModeEitherParticipantScores() {
        // Self-scoring enabled ⇒ no restriction; either player can score (so a
        // single device can run the whole match, points go to the striker).
        let (alice, _) = make(myUserId: "u1", selfScoringDisabled: false)
        #expect(alice.canScore == true)     // striker
        let (bob, _) = make(myUserId: "u2", selfScoringDisabled: false)
        #expect(bob.canScore == true)       // not at the table, but still allowed
    }

    @Test func selfScoringDisabledOpponentScores() {
        let (alice, _) = make(myUserId: "u1", selfScoringDisabled: true)
        #expect(alice.canScore == false)    // striker can't score self
        let (bob, _) = make(myUserId: "u2", selfScoringDisabled: true)
        #expect(bob.canScore == true)       // opponent records the break
    }

    /// Guest opponent (normal self-scoring): the registered player records the
    /// whole frame — including the guest's break — since the guest has no device.
    @Test func guestOpponentLetsRegisteredPlayerScoreBothVisits() {
        func guestState(striker: Int) -> API.MatchLiveState {
            let base = API.MatchLiveState.sample()
            return API.MatchLiveState(
                matchId: base.matchId, status: .live, bestOf: base.bestOf,
                framesWon: [0, 0], selfScoringDisabled: false,
                participants: [.user(id: "u1", handle: "alice", displayName: "Alice"), .guest(name: "Guest")],
                frame: API.FrameState(
                    frameNumber: 1, breaker: 0, striker: striker, scores: [0, 0],
                    redsRemaining: 15, phase: .reds, colorOn: nil,
                    currentBreak: API.Break(striker: striker, points: 0),
                    pointsRemaining: 147, freeBallAvailable: false, respottedBlack: false,
                    status: .inProgress, winner: nil
                ),
                highestBreak: [0, 0], version: 1
            )
        }
        let channel = FakeMatchChannel()
        let vm = MatchScoringViewModel(channel: channel, myUserId: "u1")
        vm.start()

        channel.emit(guestState(striker: 0))   // registered player's own break
        #expect(vm.canScore == true)

        channel.emit(guestState(striker: 1))   // guest at the table → registered player still scores
        #expect(vm.canScore == true)
    }

    @Test func potSendsAction() {
        let (vm, channel) = make(myUserId: "u1")
        vm.pot(.red)
        vm.foul(points: 4)
        vm.endVisit()
        vm.undo()
        #expect(channel.sent == [.pot(.red), .foul(points: 4), .endVisit, .undo])
    }

    @Test func actionEventNamesMatchContract() {
        #expect(ScoringAction.pot(.black).event == "score:pot")
        #expect(ScoringAction.foul(points: 7).event == "score:foul")
        #expect(ScoringAction.freeBall.event == "score:freeBall")
        #expect(ScoringAction.endVisit.event == "score:endVisit")
        #expect(ScoringAction.concedeFrame.event == "frame:concede")
        #expect(ScoringAction.concedeMatch.event == "match:concede")
        #expect(ScoringAction.undo.event == "score:undo")
        #expect(ScoringAction.pot(.blue).payload["ball"] as? String == "blue")
        #expect(ScoringAction.foul(points: 5).payload["points"] as? Int == 5)
    }

    @Test func errorMapsToMessageAndClearsOnState() {
        let channel = FakeMatchChannel()
        let vm = MatchScoringViewModel(channel: channel, myUserId: "u1")
        vm.start()
        channel.emitError(APIError(code: "self_scoring_forbidden", message: "no", status: 409))
        #expect(vm.errorMessage == "Your opponent scores this break.")
        channel.emit(.sample())
        #expect(vm.errorMessage == nil)     // a fresh state clears the error
    }

    @Test func winnerNameWhenCompleted() {
        let channel = FakeMatchChannel()
        let vm = MatchScoringViewModel(channel: channel, myUserId: "u1")
        vm.start()
        let base = API.MatchLiveState.sample()
        let done = API.MatchLiveState(
            matchId: base.matchId, status: .completed, bestOf: base.bestOf,
            framesWon: [3, 1], selfScoringDisabled: false, participants: base.participants,
            frame: nil, highestBreak: base.highestBreak, version: 20
        )
        channel.emit(done)
        #expect(vm.isCompleted == true)
        #expect(vm.winnerName == "Alice")
        #expect(vm.canScore == false)
    }
}
