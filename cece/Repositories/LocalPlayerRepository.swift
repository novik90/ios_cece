import Foundation
import SwiftData

/// SwiftData-backed implementation of `PlayerRepository`.
@MainActor
final class LocalPlayerRepository: PlayerRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Player] {
        let descriptor = FetchDescriptor<Player>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    func create(name: String) throws -> Player {
        let player = Player(name: name)
        context.insert(player)
        try context.save()
        return player
    }

    func delete(_ player: Player) throws {
        context.delete(player)
        try context.save()
    }
}
