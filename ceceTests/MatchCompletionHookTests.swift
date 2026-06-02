import Testing
import Foundation
import SwiftData
@testable import cece

@MainActor
struct MatchCompletionHookTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Player.self, Match.self, Frame.self, Break.self,
            Tournament.self, TournamentMatch.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Completing a tournament match through MatchViewModel advances the bracket
    /// via the onMatchCompleted hook + repository — no manual advancer call and
    /// no manual refresh.
    @Test func completingTournamentMatchAdvancesBracket() throws {
        let container = try makeContainer()
        try withExtendedLifetime(container) {
            let context = container.mainContext
            let repo = LocalTournamentRepository(context: context)

            let players = (1...4).map { Player(name: "P\($0)") }
            players.forEach { context.insert($0) }
            let tournament = Tournament(name: "T", size: .four)
            context.insert(tournament)
            let nodes = BracketGenerator.makePlan(size: .four).makeMatches(players: players)
            for node in nodes {
                node.tournament = tournament
                context.insert(node)
            }
            try context.save()

            // First winners round-0 node: seat a real Match between its two players.
            let node = tournament.matches.first { $0.bracket == .winners && $0.round == 0 }!
            let byId = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
            let p1 = byId[node.slot1PlayerId!]!
            let p2 = byId[node.slot2PlayerId!]!
            let match = Match(player1: p1, player2: p2, totalFrames: 1)
            node.match = match
            context.insert(match)
            try context.save()

            // Wire the hook exactly as Dependencies does, then complete the match.
            let viewModel = MatchViewModel(match: match, context: context)
            viewModel.onMatchCompleted = { completed in
                try? repo.advanceOnCompletion(of: completed)
            }
            viewModel.concedeMatch(winnerId: p1.id)

            // Winner advanced into its destination slot; loser dropped into theirs.
            let winnerDest = tournament.matches.first { $0.id == node.winnerDestinationId }!
            let winnerSlot = node.winnerDestinationSlot == 1 ? winnerDest.slot1PlayerId : winnerDest.slot2PlayerId
            #expect(winnerSlot == p1.id)

            let loserDest = tournament.matches.first { $0.id == node.loserDestinationId }!
            let loserSlot = node.loserDestinationSlot == 1 ? loserDest.slot1PlayerId : loserDest.slot2PlayerId
            #expect(loserSlot == p2.id)
        }
    }

    /// The hook is a no-op for an ordinary (non-tournament) match.
    @Test func completingNonTournamentMatchIsHarmless() throws {
        let container = try makeContainer()
        try withExtendedLifetime(container) {
            let context = container.mainContext
            let repo = LocalTournamentRepository(context: context)

            let p1 = Player(name: "A"), p2 = Player(name: "B")
            context.insert(p1); context.insert(p2)
            let match = Match(player1: p1, player2: p2, totalFrames: 1)
            context.insert(match)
            try context.save()

            let viewModel = MatchViewModel(match: match, context: context)
            viewModel.onMatchCompleted = { try? repo.advanceOnCompletion(of: $0) }
            viewModel.concedeMatch(winnerId: p1.id)

            #expect(match.winnerId == p1.id)
            #expect(match.isCompleted)
        }
    }
}
