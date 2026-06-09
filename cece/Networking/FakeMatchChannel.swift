#if DEBUG
import Foundation

/// In-memory `MatchChannel` for previews and tests: records sent actions and lets
/// the caller push state/errors. No real scoring happens here — the server owns
/// that — so emitted states are scripted by the test/preview.
@MainActor
final class FakeMatchChannel: MatchChannel {
    var onState: ((API.MatchLiveState) -> Void)?
    var onError: ((APIError) -> Void)?
    var onConnectionChange: ((MatchChannelStatus) -> Void)?

    private(set) var sent: [ScoringAction] = []
    private(set) var started = false

    /// State emitted automatically once `start()` is called (preview convenience).
    var initialState: API.MatchLiveState?

    init(initialState: API.MatchLiveState? = nil) { self.initialState = initialState }

    func start() {
        started = true
        onConnectionChange?(.connected)
        if let initialState { onState?(initialState) }
    }

    func send(_ action: ScoringAction) { sent.append(action) }
    func stop() { onConnectionChange?(.disconnected) }

    // Test/preview helpers
    func emit(_ state: API.MatchLiveState) { onState?(state) }
    func emitError(_ error: APIError) { onError?(error) }
    func emitConnection(_ status: MatchChannelStatus) { onConnectionChange?(status) }
}

extension API.MatchLiveState {
    /// A mid-frame sample for previews/tests: A leads the frame 24–8, on a break of 24.
    static func sample(selfScoringDisabled: Bool = false) -> API.MatchLiveState {
        API.MatchLiveState(
            matchId: "m1",
            status: .live,
            bestOf: 5,
            framesWon: [1, 0],
            selfScoringDisabled: selfScoringDisabled,
            participants: [
                .user(id: "u1", handle: "alice", displayName: "Alice"),
                .user(id: "u2", handle: "bob", displayName: "Bob"),
            ],
            frame: API.FrameState(
                frameNumber: 2,
                breaker: 0,
                striker: 0,
                scores: [24, 8],
                redsRemaining: 9,
                phase: .reds,
                colorOn: nil,
                currentBreak: API.Break(striker: 0, points: 24),
                pointsRemaining: 99,
                freeBallAvailable: false,
                respottedBlack: false,
                status: .inProgress,
                winner: nil
            ),
            highestBreak: [24, 0],
            version: 7
        )
    }
}
#endif
