import Foundation
import SwiftData

/// Which half of the double-elimination bracket a node belongs to.
enum TournamentBracket: String, Codable {
    case winners
    case losers
    case grandFinal
}

/// A single node in a double-elimination bracket.
///
/// A node pairs two participant slots (`slot1PlayerId` / `slot2PlayerId`). When
/// its `match` is played and decided, the winner and loser are routed to other
/// nodes via the destination references — that routing is the bracket's wiring,
/// produced by the generator (T2) and walked by the advancement engine (T3).
///
/// Destinations are stored as the target node's `id` (plus the target slot)
/// rather than as SwiftData relationships: a node has *two* outgoing edges
/// (winner and loser) into the same model type, which a relationship inverse
/// cannot express cleanly. The owning `Tournament` holds all nodes, so lookups
/// stay local to one tournament.
@Model
final class TournamentMatch {
    @Attribute(.unique) var id: UUID

    /// Owning tournament (inverse of `Tournament.matches`).
    var tournament: Tournament?

    /// Raw bracket value; use `bracket` for the typed accessor.
    var bracketValue: String

    /// Round index within the bracket (0-based).
    var round: Int

    /// Position of the node within its round (0-based, top to bottom).
    var position: Int

    /// The actual played match, once started. Nil until the slots are filled
    /// and play begins.
    var match: Match?

    /// Player occupying the first slot, if assigned.
    var slot1PlayerId: UUID?

    /// Player occupying the second slot, if assigned.
    var slot2PlayerId: UUID?

    /// Node the winner advances into, by `TournamentMatch.id`.
    var winnerDestinationId: UUID?

    /// Slot (1 or 2) the winner fills in `winnerDestinationId`.
    var winnerDestinationSlot: Int?

    /// Node the loser drops into, by `TournamentMatch.id`. Nil when losing
    /// eliminates the player (e.g. losers-bracket and grand-final nodes).
    var loserDestinationId: UUID?

    /// Slot (1 or 2) the loser fills in `loserDestinationId`.
    var loserDestinationSlot: Int?

    /// Optional seeding slot for initial participant placement, used by the
    /// generator to seat players into the first round.
    var participantSlot: Int?

    init(
        id: UUID = UUID(),
        tournament: Tournament? = nil,
        bracket: TournamentBracket,
        round: Int,
        position: Int,
        match: Match? = nil,
        slot1PlayerId: UUID? = nil,
        slot2PlayerId: UUID? = nil,
        winnerDestinationId: UUID? = nil,
        winnerDestinationSlot: Int? = nil,
        loserDestinationId: UUID? = nil,
        loserDestinationSlot: Int? = nil,
        participantSlot: Int? = nil
    ) {
        self.id = id
        self.tournament = tournament
        self.bracketValue = bracket.rawValue
        self.round = round
        self.position = position
        self.match = match
        self.slot1PlayerId = slot1PlayerId
        self.slot2PlayerId = slot2PlayerId
        self.winnerDestinationId = winnerDestinationId
        self.winnerDestinationSlot = winnerDestinationSlot
        self.loserDestinationId = loserDestinationId
        self.loserDestinationSlot = loserDestinationSlot
        self.participantSlot = participantSlot
    }
}

extension TournamentMatch {
    /// Typed accessor over the persisted `bracketValue`. Falls back to
    /// `.winners` for unexpected stored values.
    var bracket: TournamentBracket {
        get { TournamentBracket(rawValue: bracketValue) ?? .winners }
        set { bracketValue = newValue.rawValue }
    }

    /// Whether both participant slots are filled and the node is ready to play.
    var isReady: Bool { slot1PlayerId != nil && slot2PlayerId != nil }
}
