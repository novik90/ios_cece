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
}
