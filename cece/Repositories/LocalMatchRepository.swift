import Foundation
import SwiftData

/// SwiftData-backed implementation of `MatchRepository`.
@MainActor
final class LocalMatchRepository: MatchRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Match] {
        let descriptor = FetchDescriptor<Match>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    func create(player1: Player, player2: Player, totalFrames: Int) throws -> Match {
        let match = Match(player1: player1, player2: player2, totalFrames: totalFrames)
        context.insert(match)
        try context.save()
        return match
    }

    func save() throws {
        try context.save()
    }

    func delete(_ match: Match) throws {
        context.delete(match)
        try context.save()
    }
}
