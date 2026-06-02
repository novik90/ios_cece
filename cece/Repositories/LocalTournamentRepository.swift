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

    func advanceOnCompletion(of match: Match) throws {
        // Tournament data is small; an in-memory scan over the bracket nodes is
        // simpler and more robust than predicating on an optional relationship.
        let nodes = try context.fetch(FetchDescriptor<TournamentMatch>())
        guard let node = nodes.first(where: { $0.match?.id == match.id }),
              let tournament = node.tournament else { return }
        TournamentAdvancer.recordResult(for: node, in: tournament)
        try context.save()
    }
}
