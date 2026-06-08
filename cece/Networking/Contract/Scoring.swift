import Foundation

extension API {
    enum Ball: String, Codable, Equatable {
        case red, yellow, green, brown, blue, pink, black

        var points: Int {
            switch self {
            case .red: return 1
            case .yellow: return 2
            case .green: return 3
            case .brown: return 4
            case .blue: return 5
            case .pink: return 6
            case .black: return 7
            }
        }
    }

    enum FramePhase: String, Codable, Equatable {
        case reds, colors
    }

    enum FrameStatus: String, Codable, Equatable {
        case inProgress = "in_progress"
        case completed
    }

    /// Live counter for the current visit.
    struct Break: Codable, Equatable {
        let striker: Slot
        let points: Int
    }

    struct FrameState: Codable, Equatable {
        let frameNumber: Int
        let breaker: Slot
        let striker: Slot
        let scores: [Int]
        let redsRemaining: Int
        let phase: FramePhase
        let colorOn: Ball?
        let currentBreak: Break
        let pointsRemaining: Int
        let freeBallAvailable: Bool
        let respottedBlack: Bool
        let status: FrameStatus
        let winner: Slot?
    }

    /// Full live state the server broadcasts to a match room (contract v2).
    struct MatchLiveState: Codable, Equatable {
        let matchId: String
        let status: MatchStatus
        let bestOf: Int
        let framesWon: [Int]
        let selfScoringDisabled: Bool
        let participants: [Participant]
        let frame: FrameState?
        let highestBreak: [Int]
        let version: Int
    }
}
