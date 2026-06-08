import Foundation

/// Environment configuration. Dev points at a locally running cece-backend;
/// prod host is a placeholder until hosting is chosen.
enum AppConfig {
    /// REST base URL — includes the `/v1` prefix.
    static let apiBaseURL: URL = {
        #if DEBUG
        return URL(string: "http://localhost:3000/v1")!
        #else
        return URL(string: "https://api.cece.app/v1")! // TODO: real prod host
        #endif
    }()

    /// Socket.IO base — host only, no `/v1` (it is a namespace, see contract v2).
    static let socketURL: URL = {
        #if DEBUG
        return URL(string: "http://localhost:3000")!
        #else
        return URL(string: "https://api.cece.app")!
        #endif
    }()
}
