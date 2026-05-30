import Foundation

/// Abstraction over match persistence.
///
/// See `PlayerRepository` for the rationale behind the protocol boundary.
@MainActor
protocol MatchRepository {
    func fetchAll() throws -> [Match]
    func create(player1: Player, player2: Player, totalFrames: Int) throws -> Match
    func save() throws
    func delete(_ match: Match) throws
}
