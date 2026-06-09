import Foundation

/// A scoring action the client sends to the server (contract v2 `WS_CLIENT_EVENTS`).
/// Frame/match completion is derived server-side, never sent.
enum ScoringAction: Equatable {
    case pot(API.Ball)
    case foul(points: Int)
    case freeBall
    case endVisit
    case concedeFrame
    case concedeMatch
    case undo

    /// Socket.IO event name.
    var event: String {
        switch self {
        case .pot: return "score:pot"
        case .foul: return "score:foul"
        case .freeBall: return "score:freeBall"
        case .endVisit: return "score:endVisit"
        case .concedeFrame: return "frame:concede"
        case .concedeMatch: return "match:concede"
        case .undo: return "score:undo"
        }
    }

    /// JSON payload for the event (empty object for no-payload actions).
    var payload: [String: Any] {
        switch self {
        case let .pot(ball): return ["ball": ball.rawValue]
        case let .foul(points): return ["points": points]
        default: return [:]
        }
    }
}

/// Connection lifecycle of a `MatchChannel`.
enum MatchChannelStatus: Equatable { case connecting, connected, disconnected }

/// Transport-agnostic live connection to a single match room.
///
/// The scoring UI talks only to this protocol; the Socket.IO implementation
/// (`SocketIOMatchChannel`) lands in block F2. A channel is created bound to one
/// match: `start()` connects and joins the room, `send` dispatches an action,
/// and the server pushes authoritative state back through `onState`.
@MainActor
protocol MatchChannel: AnyObject {
    var onState: ((API.MatchLiveState) -> Void)? { get set }
    var onError: ((APIError) -> Void)? { get set }
    var onConnectionChange: ((MatchChannelStatus) -> Void)? { get set }

    func start()
    func send(_ action: ScoringAction)
    func stop()
}
