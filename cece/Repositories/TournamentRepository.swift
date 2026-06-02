import Foundation

/// Abstraction over tournament persistence.
///
/// See `PlayerRepository` for the rationale behind the protocol boundary.
@MainActor
protocol TournamentRepository {
    func fetchAll() throws -> [Tournament]
    func create(name: String, size: TournamentSize) throws -> Tournament
    func save() throws
    func delete(_ tournament: Tournament) throws

    /// If `match` is a tournament match, advance its bracket from the result.
    /// No-op for non-tournament matches or matches without a recorded winner.
    func advanceOnCompletion(of match: Match) throws
}
