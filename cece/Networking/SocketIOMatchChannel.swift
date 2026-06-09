import Foundation
import SocketIO

/// Socket.IO implementation of `MatchChannel` (contract v2 real-time scoring).
///
/// On `start()` it connects to the match namespace, authenticating with the
/// access token via the handshake `Authorization` header. On every (re)connect
/// it emits `match:join`; the server replies with the full `match:state`, which
/// it also re-broadcasts after each applied action. Action acks carry either
/// `{ ok, version }` or the `{ error }` envelope.
@MainActor
final class SocketIOMatchChannel: MatchChannel {
    var onState: ((API.MatchLiveState) -> Void)?
    var onError: ((APIError) -> Void)?
    var onConnectionChange: ((MatchChannelStatus) -> Void)?

    private let matchId: String
    private let manager: SocketManager
    private let socket: SocketIOClient
    private let decoder = JSONDecoder.cece

    init(matchId: String, socketURL: URL = AppConfig.socketURL, token: String?) {
        self.matchId = matchId
        var config: SocketIOClientConfiguration = [
            .log(false),
            .compress,
            .reconnects(true),
            .reconnectWait(1),
            .reconnectWaitMax(5),
        ]
        if let token { config.insert(.extraHeaders(["Authorization": "Bearer \(token)"])) }
        self.manager = SocketManager(socketURL: socketURL, config: config)
        self.socket = manager.defaultSocket
        registerHandlers()
    }

    func start() {
        onConnectionChange?(.connecting)
        socket.connect()
    }

    func send(_ action: ScoringAction) {
        socket.emitWithAck(action.event, action.payload).timingOut(after: 5) { [weak self] data in
            MainActor.assumeIsolated { self?.handleAck(data) }
        }
    }

    func stop() {
        socket.disconnect()
    }

    // MARK: Handlers

    private func registerHandlers() {
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.onConnectionChange?(.connected)
                self.socket.emitWithAck("match:join", ["matchId": self.matchId]).timingOut(after: 5) { [weak self] data in
                    MainActor.assumeIsolated { self?.handleAck(data) }
                }
            }
        }
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.onConnectionChange?(.disconnected) }
        }
        socket.on(clientEvent: .reconnectAttempt) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.onConnectionChange?(.connecting) }
        }
        socket.on(clientEvent: .error) { [weak self] data, _ in
            MainActor.assumeIsolated {
                self?.onError?(APIError(code: "network_error", message: Self.describe(data), status: 0))
            }
        }
        socket.on("match:state") { [weak self] data, _ in
            MainActor.assumeIsolated { self?.handleState(data.first) }
        }
        socket.on("match:error") { [weak self] data, _ in
            MainActor.assumeIsolated { self?.handleAck(data) }
        }
    }

    private func handleState(_ raw: Any?) {
        guard let raw, let state = decode(API.MatchLiveState.self, from: raw) else { return }
        onState?(state)
    }

    /// Acks (and `match:error`) are `{ ok, version }` or `{ error: { code, message } }`.
    private func handleAck(_ data: [Any]) {
        guard let dict = data.first as? [String: Any] else { return }
        guard let error = dict["error"] as? [String: Any] else { return } // ok ⇒ state arrives via broadcast
        onError?(APIError(
            code: error["code"] as? String ?? "error",
            message: error["message"] as? String ?? "Action failed",
            status: 0
        ))
    }

    private func decode<T: Decodable>(_ type: T.Type, from raw: Any) -> T? {
        guard JSONSerialization.isValidJSONObject(raw),
              let data = try? JSONSerialization.data(withJSONObject: raw) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private static func describe(_ data: [Any]) -> String {
        if let message = data.first as? String { return message }
        if let dict = data.first as? [String: Any], let message = dict["message"] as? String { return message }
        return "Connection error"
    }
}
