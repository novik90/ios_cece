import SwiftUI

/// The seven snooker ball types, raw value = point value.
enum SnookerBall: Int, CaseIterable, Hashable {
    case red    = 1
    case yellow = 2
    case green  = 3
    case brown  = 4
    case blue   = 5
    case pink   = 6
    case black  = 7

    /// Fill colour — reuses the shared palette in `Theme.Ball`.
    var color: Color { Theme.Ball.color(forPoints: rawValue) }

    /// Foreground colour for a numeral drawn on the ball.
    var textColor: Color {
        self == .yellow ? Color.black.opacity(0.6) : .white
    }

    /// Colours in the order they must be potted during the colours phase.
    static let colourSequence: [SnookerBall] = [.yellow, .green, .brown, .blue, .pink, .black]
}

/// Phase of a frame: potting reds (with colours in between) or the final
/// colour sequence.
enum GamePhase: Hashable {
    case reds
    case colors
}

/// A single reversible action, recorded for the undo stack.
enum MatchAction {
    case ballPotted(playerId: UUID, ball: SnookerBall)
    case foul(penaltyPoints: Int, receivingPlayerId: UUID, nextPlayerId: UUID)
    case endBreak(fromPlayerId: UUID, toPlayerId: UUID)
    case endFrame(winnerId: UUID)
    /// Manual correction from the Edit menu (reds adjustment, match concession).
    case edit
}
