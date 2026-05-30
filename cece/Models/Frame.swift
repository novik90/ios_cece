import Foundation
import SwiftData

@Model
final class Frame {
    @Attribute(.unique) var id: UUID
    var frameNumber: Int

    @Relationship(deleteRule: .cascade, inverse: \Break.frame)
    var breaks: [Break]

    var player1Score: Int
    var player2Score: Int
    var winnerId: UUID?

    // Inverse relationship back to the owning match.
    var match: Match?

    init(
        id: UUID = UUID(),
        frameNumber: Int,
        breaks: [Break] = [],
        player1Score: Int = 0,
        player2Score: Int = 0,
        winnerId: UUID? = nil
    ) {
        self.id = id
        self.frameNumber = frameNumber
        self.breaks = breaks
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.winnerId = winnerId
    }
}
