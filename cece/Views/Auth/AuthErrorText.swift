import Foundation

/// Maps API errors to user-facing auth messages.
/// (English for now; localization of auth strings is a follow-up.)
enum AuthErrorText {
    static func message(_ error: Error) -> String {
        guard let api = error as? APIError else { return "Something went wrong. Please try again." }
        switch api.code {
        case "invalid_credentials": return "Invalid email or password."
        case "email_taken": return "That email is already registered."
        case "handle_taken": return "That handle is already taken."
        case "validation_error": return "Please check the form and try again."
        case "network_error": return "No connection. Check your internet and try again."
        default: return api.message
        }
    }
}
