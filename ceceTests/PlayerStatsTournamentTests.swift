import Testing
import Foundation
import SwiftData
@testable import cece

@MainActor
struct PlayerStatsTournamentTests {

    private func makeTournament(_ context: ModelContext, name: String, players: [Player], champion: Player?) -> Tournament {
        let tournament = Tournament(name: name, size: .four)
        if let champion { tournament.championId = champion.id; tournament.completedAt = .now }
        context.insert(tournament)
        for node in BracketGenerator.makePlan(size: .four).makeMatches(players: players) {
            node.tournament = tournament
            context.insert(node)
        }
        return tournament
    }

    @Test func playerTournamentParticipationAndWins() throws {
        let container = try ModelContainer(
            for: Player.self, Match.self, Frame.self, Break.self,
            Tournament.self, TournamentMatch.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        try withExtendedLifetime(container) {
            let context = container.mainContext
            let field = (1...4).map { Player(name: "P\($0)") }
            let others = (5...8).map { Player(name: "P\($0)") }
            (field + others).forEach { context.insert($0) }
            let hero = field[0]

            // Hero participates in A (champion) and B (lost); not in C.
            let a = makeTournament(context, name: "A", players: field, champion: hero)
            let b = makeTournament(context, name: "B", players: field, champion: field[1])
            _ = makeTournament(context, name: "C", players: others, champion: others[0])
            try context.save()

            let allTournaments = try LocalTournamentRepository(context: context).fetchAll()
            let stats = PlayerStats(player: hero, matches: [], tournaments: allTournaments)

            #expect(stats.tournamentsPlayed.count == 2)
            #expect(Set(stats.tournamentsPlayed.map(\.name)) == ["A", "B"])
            #expect(stats.tournamentsWon == 1)

            let aStat = stats.tournamentsPlayed.first { $0.name == "A" }
            let bStat = stats.tournamentsPlayed.first { $0.name == "B" }
            #expect(aStat?.didWin == true)
            #expect(bStat?.didWin == false)
            _ = (a, b)
        }
    }

    @Test func playerWithoutTournamentsHasNone() throws {
        let player = Player(name: "Solo")
        let stats = PlayerStats(player: player, matches: [], tournaments: [])
        #expect(stats.tournamentsPlayed.isEmpty)
        #expect(stats.tournamentsWon == 0)
    }
}
