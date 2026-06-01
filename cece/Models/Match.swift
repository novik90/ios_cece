import Foundation
import SwiftData

@Model
final class Match {
    @Attribute(.unique) var id: UUID

    // Relationships to players. Optional to satisfy SwiftData's requirement that
    // referenced models can be nil during inserts / deletes.
    var player1: Player?
    var player2: Player?

    /// Best-of-N: total number of frames the match can run to.
    var totalFrames: Int

    @Relationship(deleteRule: .cascade, inverse: \Frame.match)
    var frames: [Frame]

    var createdAt: Date
    var completedAt: Date?

    /// Explicit match winner, if recorded. When nil, the winner is derived from
    /// frames won (see `PlayerStats.winnerId(of:)`).
    var winnerId: UUID?

    init(
        id: UUID = UUID(),
        player1: Player,
        player2: Player,
        totalFrames: Int,
        frames: [Frame] = [],
        createdAt: Date = .now,
        completedAt: Date? = nil,
        winnerId: UUID? = nil
    ) {
        self.id = id
        self.player1 = player1
        self.player2 = player2
        self.totalFrames = totalFrames
        self.frames = frames
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.winnerId = winnerId
    }
}

extension Match {
    /// Number of frames each player needs to win the match (best of N).
    var framesToWin: Int { totalFrames / 2 + 1 }

    var isCompleted: Bool { completedAt != nil }

    func framesWon(by player: Player?) -> Int {
        guard let id = player?.id else { return 0 }
        return frames.filter { $0.winnerId == id }.count
    }
}
