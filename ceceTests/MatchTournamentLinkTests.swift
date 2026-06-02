import Testing
import Foundation
import SwiftData
@testable import cece

@MainActor
struct MatchTournamentLinkTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Player.self, Match.self, Frame.self, Break.self,
            Tournament.self, TournamentMatch.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Assigning a node's match links the inverse, so the match can identify its
    /// tournament.
    @Test func linkedMatchResolvesItsTournament() throws {
        let container = try makeContainer()
        try withExtendedLifetime(container) {
            let context = container.mainContext
            let players = (1...4).map { Player(name: "P\($0)") }
            players.forEach { context.insert($0) }
            let tournament = Tournament(name: "Cup", size: .four)
            context.insert(tournament)
            for node in BracketGenerator.makePlan(size: .four).makeMatches(players: players) {
                node.tournament = tournament
                context.insert(node)
            }
            try context.save()

            let node = tournament.matches.first { $0.bracket == .winners && $0.round == 0 }!
            let byId = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
            let match = Match(player1: byId[node.slot1PlayerId!]!, player2: byId[node.slot2PlayerId!]!, totalFrames: 3)
            node.match = match  // sets the inverse Match.tournamentMatch automatically
            context.insert(match)
            try context.save()

            #expect(match.isTournamentMatch)
            #expect(match.tournamentMatch?.id == node.id)
            #expect(match.tournament?.id == tournament.id)
        }
    }

    /// An ordinary match is not part of any tournament.
    @Test func ordinaryMatchHasNoTournament() throws {
        let container = try makeContainer()
        try withExtendedLifetime(container) {
            let context = container.mainContext
            let p1 = Player(name: "A"), p2 = Player(name: "B")
            context.insert(p1); context.insert(p2)
            let match = Match(player1: p1, player2: p2, totalFrames: 3)
            context.insert(match)
            try context.save()

            #expect(match.isTournamentMatch == false)
            #expect(match.tournament == nil)
            #expect(match.tournamentMatch == nil)
        }
    }
}
