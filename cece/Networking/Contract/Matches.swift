import Foundation

extension API {
    enum MatchStatus: String, Codable, Equatable {
        case scheduled, live, completed
    }

    /// Match list item (contract v1).
    struct MatchSummary: Codable, Identifiable, Equatable {
        let id: String
        let participants: [Participant]   // exactly 2, index-aligned with framesWon
        let bestOf: Int
        let status: MatchStatus
        let framesWon: [Int]              // [slot0, slot1]
        let winner: Participant?
        let createdAt: Date
        let completedAt: Date?
    }

    /// Full match (contract v1: `MatchSummary & { ownerId, activeScorerUserId? }`).
    struct Match: Codable, Identifiable, Equatable {
        let id: String
        let participants: [Participant]
        let bestOf: Int
        let status: MatchStatus
        let framesWon: [Int]
        let winner: Participant?
        let createdAt: Date
        let completedAt: Date?
        let ownerId: String
        let activeScorerUserId: String?
    }
}
