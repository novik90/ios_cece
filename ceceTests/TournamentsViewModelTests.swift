import Testing
import Foundation
import SwiftData
@testable import cece

@MainActor
struct TournamentsViewModelTests {

    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let container = try ModelContainer(
            for: Player.self, Match.self, Frame.self, Break.self,
            Tournament.self, TournamentMatch.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, container.mainContext)
    }

    @discardableResult
    private func seedTournament(_ context: ModelContext, name: String, completed: Bool) -> (Tournament, [Player]) {
        let players = (1...4).map { Player(name: "\(name)-P\($0)") }
        players.forEach { context.insert($0) }
        let tournament = Tournament(name: name, size: .four)
        if completed { tournament.completedAt = .now; tournament.championId = players[0].id }
        context.insert(tournament)
        for node in BracketGenerator.makePlan(size: .four).makeMatches(players: players) {
            node.tournament = tournament
            context.insert(node)
        }
        try? context.save()
        return (tournament, players)
    }

    @Test func loadSplitsActiveAndCompleted() throws {
        let (container, context) = try makeContext()
        try withExtendedLifetime(container) {
            seedTournament(context, name: "Active", completed: false)
            seedTournament(context, name: "Done", completed: true)

            let vm = TournamentsViewModel(repository: LocalTournamentRepository(context: context))
            vm.load()

            #expect(vm.tournaments.count == 2)
            #expect(vm.active.map(\.name) == ["Active"])
            #expect(vm.completed.map(\.name) == ["Done"])
        }
    }

    @Test func deleteCascadesNodesAndLinkedMatches() throws {
        let (container, context) = try makeContext()
        try withExtendedLifetime(container) {
            let (tournament, players) = seedTournament(context, name: "Cup", completed: false)

            // Start a real match on one node so there is a linked Match to clean up.
            let node = tournament.matches.first { $0.bracket == .winners && $0.round == 0 }!
            let byId = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
            let match = Match(player1: byId[node.slot1PlayerId!]!, player2: byId[node.slot2PlayerId!]!, totalFrames: 1)
            node.match = match
            context.insert(match)
            try? context.save()

            let vm = TournamentsViewModel(repository: LocalTournamentRepository(context: context))
            vm.load()
            vm.delete(tournament)

            let remainingTournaments = try context.fetch(FetchDescriptor<Tournament>())
            let remainingNodes = try context.fetch(FetchDescriptor<TournamentMatch>())
            let remainingMatches = try context.fetch(FetchDescriptor<Match>())
            #expect(remainingTournaments.isEmpty)
            #expect(remainingNodes.isEmpty)
            #expect(remainingMatches.isEmpty)
            #expect(vm.tournaments.isEmpty)
        }
    }
}
