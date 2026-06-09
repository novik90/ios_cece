import Foundation

/// Drives the live scoring screen from server-pushed `MatchLiveState`.
///
/// The view model holds no scoring logic — the server is authoritative. It keeps
/// the latest state, derives a few view conveniences (my seat, whose turn it is,
/// whether I'm the one allowed to score this visit), and forwards button taps as
/// `ScoringAction`s through the `MatchChannel`.
@MainActor
final class MatchScoringViewModel: ObservableObject {
    @Published private(set) var state: API.MatchLiveState?
    @Published private(set) var connection: MatchChannelStatus = .connecting
    @Published var errorMessage: String?

    private let channel: MatchChannel
    /// The signed-in user's id, used to locate my seat (nil ⇒ spectator).
    let myUserId: String?

    init(channel: MatchChannel, myUserId: String?) {
        self.channel = channel
        self.myUserId = myUserId
        channel.onState = { [weak self] in self?.state = $0; self?.errorMessage = nil }
        channel.onError = { [weak self] in self?.errorMessage = Self.message(for: $0) }
        channel.onConnectionChange = { [weak self] in self?.connection = $0 }
    }

    func start() { channel.start() }
    func stop() { channel.stop() }

    // MARK: Derived

    var frame: API.FrameState? { state?.frame }
    var isCompleted: Bool { state?.status == .completed }
    var selfScoringDisabled: Bool { state?.selfScoringDisabled ?? false }

    /// My seat in the match (0/1), or nil if I'm only spectating.
    var mySlot: Int? {
        guard let myUserId, let participants = state?.participants else { return nil }
        return participants.firstIndex { $0.userId == myUserId }
    }

    /// Whether the player at the table is me.
    var iAmStriker: Bool {
        guard let mySlot, let frame else { return false }
        return frame.striker == mySlot
    }

    /// The seat whose operator records the current striker's visit. Mirrors the
    /// server rule (`self_scoring_forbidden` only blocks the striker's own
    /// pot/freeBall when self-scoring is disabled):
    /// - a guest never operates a device, so the registered player scores for them;
    /// - with self-scoring disabled, the opponent records the striker's break;
    /// - otherwise the striker scores their own break.
    private var scorerSlot: Int? {
        guard let frame, let participants = state?.participants, participants.count == 2 else { return nil }
        let striker = frame.striker
        if participants.indices.contains(striker), participants[striker].isGuest {
            return participants.firstIndex { !$0.isGuest }
        }
        if selfScoringDisabled { return striker == 0 ? 1 : 0 }
        return striker
    }

    /// Whether *I* record this visit (i.e. the action buttons are shown to me).
    var canScore: Bool {
        guard let mySlot, !isCompleted, frame != nil else { return false }
        return mySlot == scorerSlot
    }

    /// Winner's display name once the match is completed.
    var winnerName: String? {
        guard isCompleted, let participants = state?.participants, let framesWon = state?.framesWon,
              framesWon.count == 2, framesWon[0] != framesWon[1] else { return nil }
        return participants[framesWon[0] > framesWon[1] ? 0 : 1].displayName
    }

    // MARK: Actions

    func pot(_ ball: API.Ball) { channel.send(.pot(ball)) }
    func foul(points: Int) { channel.send(.foul(points: points)) }
    func freeBall() { channel.send(.freeBall) }
    func endVisit() { channel.send(.endVisit) }
    func concedeFrame() { channel.send(.concedeFrame) }
    func concedeMatch() { channel.send(.concedeMatch) }
    func undo() { channel.send(.undo) }

    static func message(for error: APIError) -> String {
        switch error.code {
        case "self_scoring_forbidden": return "Your opponent scores this break."
        case "not_your_turn": return "It isn't this player's turn."
        case "illegal_action", "validation_error": return "That action isn't allowed right now."
        case "match_not_found": return "Match not found."
        case "forbidden": return "You can't score this match."
        case "network_error": return "Connection lost. Reconnecting…"
        default: return error.message.isEmpty ? "Something went wrong." : error.message
        }
    }
}
