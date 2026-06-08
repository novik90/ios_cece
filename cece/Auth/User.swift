import Foundation

/// Account, mirrors the backend `User` (contract v1).
struct User: Codable, Identifiable, Equatable {
    let id: String
    let handle: String
    let displayName: String
    let email: String
    let createdAt: Date
}
