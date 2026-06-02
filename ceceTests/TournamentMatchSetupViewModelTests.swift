import Testing
import Foundation
import SwiftData
@testable import cece

@MainActor
struct TournamentMatchSetupViewModelTests {

    private func makeTournament() throws -> (ModelContainer, Dependencies, Tournament, [Player]) {
        let container = try ModelContainer(
            for: Player.self, Match.self, Frame.self, Break.self,
            Tournament.self, TournamentMatch.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
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
        return (container, Dependencies(context: context), tournament, players)
    }

    private func round0Nodes(_ tournament: Tournament) -> [TournamentMatch] {
        tournament.matches
            .filter { $0.bracket == .winners && $0.round == 0 }
            .sorted { $0.position < $1.position }
    }

    @Test func startMatchLinksNodeWithChosenBestOf() throws {
        let (container, deps, tournament, _) = try makeTournament()
        try withExtendedLifetime(container) {
            let node = round0Nodes(tournament)[0]
            let vm = TournamentMatchSetupViewModel(node: node, dependencies: deps)
            vm.loadPlayers()
            vm.totalFrames = 7

            let match = vm.startMatch()
            #expect(match != nil)
            #expect(match?.totalFrames == 7)
            #expect(node.match?.id == match?.id)
        }
    }

    @Test func bestOfIsChosenPerMatch() throws {
        let (container, deps, tournament, _) = try makeTournament()
        try withExtendedLifetime(container) {
            let nodes = round0Nodes(tournament)

            let vm0 = TournamentMatchSetupViewModel(node: nodes[0], dependencies: deps)
            vm0.loadPlayers(); vm0.totalFrames = 3
            let m0 = vm0.startMatch()

            let vm1 = TournamentMatchSetupViewModel(node: nodes[1], dependencies: deps)
            vm1.loadPlayers(); vm1.totalFrames = 9
            let m1 = vm1.startMatch()

            #expect(m0?.totalFrames == 3)
            #expect(m1?.totalFrames == 9)
        }
    }

    @Test func startMatchResumesExistingInsteadOfRecreating() throws {
        let (container, deps, tournament, _) = try makeTournament()
        try withExtendedLifetime(container) {
            let node = round0Nodes(tournament)[0]
            let vm = TournamentMatchSetupViewModel(node: node, dependencies: deps)
            vm.loadPlayers()
            let first = vm.startMatch()

            vm.totalFrames = 35  // changing the format must not spawn a new match
            let second = vm.startMatch()

            #expect(first?.id == second?.id)
            #expect(vm.canStart == false)  // a match already exists
        }
    }

    @Test func completingStartedMatchAdvancesBracket() throws {
        let (container, deps, tournament, players) = try makeTournament()
        try withExtendedLifetime(container) {
            let node = round0Nodes(tournament)[0]
            let vm = TournamentMatchSetupViewModel(node: node, dependencies: deps)
            vm.loadPlayers()
            let match = vm.startMatch()!

            // Open through the live view model (wires the completion hook) and finish.
            let live = deps.liveMatchViewModel(for: match)
            let winnerId = node.slot1PlayerId!
            live.concedeMatch(winnerId: winnerId)

            let dest = tournament.matches.first { $0.id == node.winnerDestinationId }!
            let destSlot = node.winnerDestinationSlot == 1 ? dest.slot1PlayerId : dest.slot2PlayerId
            #expect(destSlot == winnerId)
            _ = players
        }
    }
}
