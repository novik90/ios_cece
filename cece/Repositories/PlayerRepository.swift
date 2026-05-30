import Foundation

/// Abstraction over player persistence.
///
/// UI/ViewModels depend only on this protocol, so the SwiftData-backed
/// `LocalPlayerRepository` can later be swapped for a network implementation
/// without touching the view layer.
@MainActor
protocol PlayerRepository {
    func fetchAll() throws -> [Player]
    func create(name: String) throws -> Player
    func delete(_ player: Player) throws
}
