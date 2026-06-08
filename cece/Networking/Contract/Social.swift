import Foundation

extension API {
    enum FriendRequestDirection: String, Codable, Equatable {
        case incoming, outgoing
    }

    struct FriendRequest: Codable, Identifiable, Equatable {
        let id: String
        let user: PublicUser            // the other party
        let direction: FriendRequestDirection
        let createdAt: Date
    }

    enum MatchInviteStatus: String, Codable, Equatable {
        case pending, accepted, declined, cancelled, expired
    }

    struct MatchInvite: Codable, Identifiable, Equatable {
        let id: String
        let from: PublicUser
        let to: PublicUser
        let bestOf: Int
        let selfScoringDisabled: Bool
        let firstBreaker: Slot          // 0 = sender, 1 = invitee
        let status: MatchInviteStatus
        let matchId: String?            // set once accepted
        let createdAt: Date
        let expiresAt: Date
    }
}
