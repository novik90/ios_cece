import Foundation
import SwiftData

@Model
final class Break {
    @Attribute(.unique) var id: UUID
    var playerId: UUID

    /// Points of each potted ball in order, e.g. [1, 7, 1, 5, 1, 6].
    var balls: [Int]

    /// Sum of the break.
    var points: Int

    // Inverse relationship back to the owning frame.
    var frame: Frame?

    init(
        id: UUID = UUID(),
        playerId: UUID,
        balls: [Int] = [],
        points: Int = 0
    ) {
        self.id = id
        self.playerId = playerId
        self.balls = balls
        self.points = points
    }
}
