import Foundation

/// Typed API error. `status` is the HTTP status, or `0` for client-side
/// failures (transport / decoding). `code` mirrors the server error envelope
/// `{ "error": { "code", "message" } }`.
struct APIError: Error, Equatable {
    let code: String
    let message: String
    let status: Int

    var isUnauthorized: Bool { status == 401 }

    static func transport(_ message: String) -> APIError {
        APIError(code: "network_error", message: message, status: 0)
    }

    static func decoding(_ message: String) -> APIError {
        APIError(code: "decoding_error", message: message, status: 0)
    }
}
