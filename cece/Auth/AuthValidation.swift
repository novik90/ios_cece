import Foundation

/// Client-side pre-validation mirroring the backend's zod rules, so the user
/// gets instant feedback before a `422`.
enum AuthValidation {
    /// Handle: lowercase, starts with a letter, 3–20 chars of [a-z0-9_].
    static func isValidHandle(_ value: String) -> Bool {
        value.range(of: "^[a-z][a-z0-9_]{2,19}$", options: .regularExpression) != nil
    }

    /// Password: 8–72 characters (bcrypt input limit).
    static func isValidPassword(_ value: String) -> Bool {
        (8...72).contains(value.count)
    }

    static func isValidEmail(_ value: String) -> Bool {
        value.range(of: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", options: .regularExpression) != nil
    }

    static func isValidDisplayName(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
