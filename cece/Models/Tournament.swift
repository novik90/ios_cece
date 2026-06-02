import Foundation
import SwiftData

/// Supported tournament field sizes. Double-elimination brackets are generated
/// for 4, 8, or 16 participants.
enum TournamentSize: Int, Codable, CaseIterable {
    case four = 4
    case eight = 8
    case sixteen = 16
}

@Model
final class Tournament {
    @Attribute(.unique) var id: UUID
    var name: String

    /// Number of participants (4 / 8 / 16). Stored as the raw `Int`; use
    /// `size` for the typed accessor.
    var sizeValue: Int

    var createdAt: Date
    var completedAt: Date?

    /// Winner of the grand final, once the tournament is decided.
    var championId: UUID?

    @Relationship(deleteRule: .cascade, inverse: \TournamentMatch.tournament)
    var matches: [TournamentMatch]

    init(
        id: UUID = UUID(),
        name: String,
        size: TournamentSize,
        createdAt: Date = .now,
        completedAt: Date? = nil,
        championId: UUID? = nil,
        matches: [TournamentMatch] = []
    ) {
        self.id = id
        self.name = name
        self.sizeValue = size.rawValue
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.championId = championId
        self.matches = matches
    }
}

extension Tournament {
    /// Typed accessor over the persisted `sizeValue`. Falls back to `.four`
    /// for unexpected stored values.
    var size: TournamentSize {
        get { TournamentSize(rawValue: sizeValue) ?? .four }
        set { sizeValue = newValue.rawValue }
    }

    var isCompleted: Bool { completedAt != nil }
}
