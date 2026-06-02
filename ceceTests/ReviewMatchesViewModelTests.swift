import Testing
import Foundation
import SwiftData
@testable import cece

@MainActor
struct ReviewMatchesViewModelTests {

    /// A completed tournament match and a completed ordinary match are split into
    /// the right buckets.
    @Test func splitsTournamentAndOrdinaryMatches() throws {
        let container = try ModelContainer(
            for: Player.self, Match.self, Frame.self, Break.self,
            Tournament.self, TournamentMatch.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        try withExtendedLifetime(container) {
            let context = container.mainContext
            let players = (1...4).map { Player(name: "P\($0)") }
            players.forEach { context.insert($0) }

            // Ordinary completed match.
            let ordinary = Match(player1: players[0], player2: players[1], totalFrames: 1)
            ordinary.winnerId = players[0].id
            ordinary.completedAt = .now
            context.insert(ordinary)

            // Tournament + a completed match linked to a bracket node.
            let tournament = Tournament(name: "Cup", size: .four)
            context.insert(tournament)
            for node in BracketGenerator.makePlan(size: .four).makeMatches(players: players) {
                node.tournament = tournament
                context.insert(node)
            }
            let node = tournament.matches.first { $0.bracket == .winners && $0.round == 0 }!
            let byId = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
            let tMatch = Match(player1: byId[node.slot1PlayerId!]!, player2: byId[node.slot2PlayerId!]!, totalFrames: 1)
            node.match = tMatch
            tMatch.winnerId = node.slot1PlayerId
            tMatch.completedAt = .now
            context.insert(tMatch)
            try context.save()

            let vm = ReviewMatchesViewModel(repository: LocalMatchRepository(context: context))
            vm.load()

            #expect(vm.matches.count == 2)
            #expect(vm.tournamentMatches.map(\.id) == [tMatch.id])
            #expect(vm.otherMatches.map(\.id) == [ordinary.id])
        }
    }
}
