import Foundation
import SwiftData

/// SwiftData-backed implementation of `TournamentRepository`.
@MainActor
final class LocalTournamentRepository: TournamentRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Tournament] {
        let descriptor = FetchDescriptor<Tournament>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    func create(name: String, size: TournamentSize) throws -> Tournament {
        let tournament = Tournament(name: name, size: size)
        context.insert(tournament)
        try context.save()
        return tournament
    }

    func save() throws {
        try context.save()
    }

    func delete(_ tournament: Tournament) throws {
        context.delete(tournament)
        try context.save()
    }
}
