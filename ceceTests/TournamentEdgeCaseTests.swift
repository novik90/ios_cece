import Testing
import Foundation
import SwiftData
@testable import cece

/// Edge cases and end-to-end coverage for the tournament engine across all
/// sizes, plus mid-tournament data mutations.
@MainActor
struct TournamentEdgeCaseTests {

    private func makeTournament(size: TournamentSize) throws -> (ModelContainer, ModelContext, Tournament, [Player]) {
        let container = try ModelContainer(
            for: Player.self, Match.self, Frame.self, Break.self,
            Tournament.self, TournamentMatch.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let players = (1...size.rawValue).map { Player(name: "P\($0)") }
        players.forEach { context.insert($0) }
        let tournament = Tournament(name: "Cup", size: size)
        context.insert(tournament)
        for node in BracketGenerator.makePlan(size: size).makeMatches(players: players) {
            node.tournament = tournament
            context.insert(node)
        }
        try context.save()
        return (container, context, tournament, players)
    }

    /// Plays the whole tournament with the better seed always winning.
    private func playOutSeedFavored(_ tournament: Tournament, players: [Player]) {
        let seedOf = Dictionary(uniqueKeysWithValues: players.enumerated().map { ($1.id, $0) })
        var played: Set<UUID> = []
        while tournament.championId == nil {
            guard let node = tournament.matches.first(where: {
                !played.contains($0.id) && $0.slot1PlayerId != nil && $0.slot2PlayerId != nil
            }) else { break }
            let winner = seedOf[node.slot1PlayerId!]! < seedOf[node.slot2PlayerId!]!
                ? node.slot1PlayerId! : node.slot2PlayerId!
            TournamentAdvancer.recordWinner(winner, of: node, in: tournament)
            played.insert(node.id)
        }
    }

    // MARK: Full run for every size

    @Test(arguments: [TournamentSize.four, .eight, .sixteen])
    func seedFavoredRunCrownsTopSeed(size: TournamentSize) throws {
        let (container, _, tournament, players) = try makeTournament(size: size)
        withExtendedLifetime(container) {
            playOutSeedFavored(tournament, players: players)

            #expect(tournament.championId == players[0].id)
            #expect(tournament.isCompleted)
            // Every node ends up resolved (no stuck/unreachable slots).
            let allResolved = tournament.matches.allSatisfy { $0.slot1PlayerId != nil && $0.slot2PlayerId != nil }
            #expect(allResolved)
        }
    }

    // MARK: Grand final is a single match (no bracket reset)

    @Test func grandFinalDecidesImmediately() throws {
        let (container, _, tournament, players) = try makeTournament(size: .four)
        withExtendedLifetime(container) {
            // Play everything except the grand final.
            let seedOf = Dictionary(uniqueKeysWithValues: players.enumerated().map { ($1.id, $0) })
            var played: Set<UUID> = []
            while true {
                guard let node = tournament.matches.first(where: {
                    !played.contains($0.id) && $0.bracket != .grandFinal &&
                    $0.slot1PlayerId != nil && $0.slot2PlayerId != nil
                }) else { break }
                let winner = seedOf[node.slot1PlayerId!]! < seedOf[node.slot2PlayerId!]!
                    ? node.slot1PlayerId! : node.slot2PlayerId!
                TournamentAdvancer.recordWinner(winner, of: node, in: tournament)
                played.insert(node.id)
            }

            let gf = tournament.matches.first(where: { $0.bracket == .grandFinal })!
            let gfReady = gf.isReady
            let decidedEarly = tournament.championId != nil
            #expect(gfReady)
            #expect(decidedEarly == false)  // not decided until GF is played

            // Deciding the single grand-final match ends the tournament.
            let gfSlot1 = gf.slot1PlayerId!
            TournamentAdvancer.recordWinner(gfSlot1, of: gf, in: tournament)
            let championIsGFSlot1 = tournament.championId == gfSlot1
            let isCompleted = tournament.isCompleted
            let grandFinalCount = tournament.matches.filter { $0.bracket == .grandFinal }.count
            #expect(championIsGFSlot1)
            #expect(isCompleted)
            #expect(grandFinalCount == 1)
        }
    }

    // MARK: Mid-tournament data mutations don't crash

    @Test func deletingParticipantMidTournamentDoesNotCrash() throws {
        let (container, context, tournament, players) = try makeTournament(size: .four)
        try withExtendedLifetime(container) {
            // Tournament slots reference players by id, so deleting a participant
            // must not break the bracket — the UI just can't resolve the name.
            let victimId = players[0].id
            try LocalPlayerRepository(context: context).delete(players[0])

            let reloaded = try LocalTournamentRepository(context: context).fetchAll()
            #expect(reloaded.count == 1)
            #expect(reloaded[0].matches.isEmpty == false)

            let livePlayers = try LocalPlayerRepository(context: context).fetchAll()
            let namesById = Dictionary(uniqueKeysWithValues: livePlayers.map { ($0.id, $0.name) })
            let slotStillReferencesVictim = reloaded[0].matches.contains {
                $0.slot1PlayerId == victimId || $0.slot2PlayerId == victimId
            }
            let resolvesToLiveName = namesById[victimId] != nil
            #expect(slotStillReferencesVictim)        // dangling id remains
            #expect(resolvesToLiveName == false)      // resolves to no live player → "—"
        }
    }

    @Test func deletingTournamentMidMatchRemovesFramesAndBreaks() throws {
        let (container, context, tournament, players) = try makeTournament(size: .four)
        try withExtendedLifetime(container) {
            let node = tournament.matches.first { $0.bracket == .winners && $0.round == 0 }!
            let byId = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
            let match = Match(player1: byId[node.slot1PlayerId!]!, player2: byId[node.slot2PlayerId!]!, totalFrames: 3)
            node.match = match
            let frame = Frame(frameNumber: 1, player1Score: 50, player2Score: 0, winnerId: match.player1?.id)
            frame.match = match
            match.frames.append(frame)
            context.insert(match)
            context.insert(frame)
            try context.save()

            try LocalTournamentRepository(context: context).delete(tournament)

            let tournaments = try context.fetch(FetchDescriptor<Tournament>())
            let nodes = try context.fetch(FetchDescriptor<TournamentMatch>())
            let matches = try context.fetch(FetchDescriptor<Match>())
            let frames = try context.fetch(FetchDescriptor<Frame>())
            #expect(tournaments.isEmpty)
            #expect(nodes.isEmpty)
            #expect(matches.isEmpty)
            #expect(frames.isEmpty)
        }
    }
}
