import Testing
import Foundation
import SwiftData
@testable import cece

@MainActor
struct TournamentAdvancerTests {

    /// Builds an in-memory tournament of `size` players (seed i+1 == players[i]),
    /// persisted in a real SwiftData container. The container is returned so the
    /// caller can keep it alive — releasing it invalidates the model instances.
    private func makeTournament(size: TournamentSize) throws -> (ModelContainer, Tournament, [Player]) {
        let container = try ModelContainer(
            for: Player.self, Match.self, Frame.self, Break.self,
            Tournament.self, TournamentMatch.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let players = (1...size.rawValue).map { Player(name: "P\($0)") }
        players.forEach { context.insert($0) }

        let tournament = Tournament(name: "Test", size: size)
        context.insert(tournament)

        let matches = BracketGenerator.makePlan(size: size).makeMatches(players: players)
        for match in matches {
            match.tournament = tournament
            context.insert(match)
        }
        try context.save()

        return (container, tournament, players)
    }

    /// Plays out a tournament where the better seed always wins, and returns the
    /// crowned champion's id.
    private func playOutWithSeedFavored(_ tournament: Tournament, players: [Player]) -> UUID? {
        let seedOf = Dictionary(uniqueKeysWithValues: players.enumerated().map { ($1.id, $0) })
        var played: Set<UUID> = []

        while tournament.championId == nil {
            guard let node = tournament.matches.first(where: {
                !played.contains($0.id) && $0.slot1PlayerId != nil && $0.slot2PlayerId != nil
            }) else { break }

            let winner = seedOf[node.slot1PlayerId!]! < seedOf[node.slot2PlayerId!]!
                ? node.slot1PlayerId!
                : node.slot2PlayerId!
            TournamentAdvancer.recordWinner(winner, of: node, in: tournament)
            played.insert(node.id)
        }
        return tournament.championId
    }

    @Test func fourPlayerSeedFavoredYieldsTopSeedChampion() throws {
        let (container, tournament, players) = try makeTournament(size: .four)
        try withExtendedLifetime(container) {
            let champion = playOutWithSeedFavored(tournament, players: players)

            #expect(champion == players[0].id)        // seed 1 wins out
            #expect(tournament.completedAt != nil)
            #expect(tournament.isCompleted)
        }
    }

    /// The grand final is reached with both slots filled and a single match
    /// decides it (no bracket reset).
    @Test func grandFinalIsSingleMatchAndFilled() throws {
        let (container, tournament, players) = try makeTournament(size: .four)
        try withExtendedLifetime(container) {
            _ = playOutWithSeedFavored(tournament, players: players)

            let grandFinals = tournament.matches.filter { $0.bracket == .grandFinal }
            #expect(grandFinals.count == 1)
            let gf = grandFinals[0]
            #expect(gf.slot1PlayerId != nil)
            #expect(gf.slot2PlayerId != nil)
            // Champion is one of the two finalists.
            #expect(tournament.championId == gf.slot1PlayerId || tournament.championId == gf.slot2PlayerId)
        }
    }

    /// A lower seed that wins every match becomes champion — advancement follows
    /// results, not seeding.
    @Test func underdogWinningEveryMatchBecomesChampion() throws {
        let (container, tournament, players) = try makeTournament(size: .four)
        try withExtendedLifetime(container) {
            let underdog = players[3].id  // seed 4

            var played: Set<UUID> = []
            while tournament.championId == nil {
                guard let node = tournament.matches.first(where: {
                    !played.contains($0.id) && $0.slot1PlayerId != nil && $0.slot2PlayerId != nil
                }) else { break }

                // Underdog wins whenever present; otherwise lower slot wins arbitrarily.
                let winner = (node.slot1PlayerId == underdog || node.slot2PlayerId == underdog)
                    ? underdog
                    : node.slot1PlayerId!
                TournamentAdvancer.recordWinner(winner, of: node, in: tournament)
                played.insert(node.id)
            }

            #expect(tournament.championId == underdog)
        }
    }
}
