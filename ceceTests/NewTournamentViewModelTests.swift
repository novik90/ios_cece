import Testing
import Foundation
import SwiftData
@testable import cece

@MainActor
struct NewTournamentViewModelTests {

    private func makeViewModel(playerCount: Int) throws -> (ModelContainer, NewTournamentViewModel) {
        let container = try ModelContainer(
            for: Player.self, Match.self, Frame.self, Break.self,
            Tournament.self, TournamentMatch.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        (1...playerCount).forEach { context.insert(Player(name: "P\($0)")) }
        try context.save()

        let vm = NewTournamentViewModel(
            playerRepository: LocalPlayerRepository(context: context),
            tournamentRepository: LocalTournamentRepository(context: context)
        )
        vm.loadPlayers()
        return (container, vm)
    }

    @Test func cannotCreateWithEmptyName() throws {
        let (container, vm) = try makeViewModel(playerCount: 4)
        try withExtendedLifetime(container) {
            vm.name = "   "
            vm.seeds = Array(vm.players.prefix(4))
            #expect(vm.canCreate == false)
        }
    }

    @Test func cannotCreateWithIncompleteRoster() throws {
        let (container, vm) = try makeViewModel(playerCount: 4)
        try withExtendedLifetime(container) {
            vm.name = "Cup"
            vm.seeds[0] = vm.players[0]
            vm.seeds[1] = vm.players[1]
            // seeds[2], seeds[3] still nil
            #expect(vm.canCreate == false)
        }
    }

    @Test func cannotCreateWithDuplicatePlayers() throws {
        let (container, vm) = try makeViewModel(playerCount: 4)
        try withExtendedLifetime(container) {
            vm.name = "Cup"
            vm.seeds = [vm.players[0], vm.players[0], vm.players[1], vm.players[2]]
            #expect(vm.canCreate == false)
        }
    }

    @Test func canCreateWithCompleteUniqueRoster() throws {
        let (container, vm) = try makeViewModel(playerCount: 4)
        try withExtendedLifetime(container) {
            vm.name = "Cup"
            vm.seeds = Array(vm.players.prefix(4))
            #expect(vm.canCreate)
        }
    }

    @Test func changingSizeResizesSeedsAndRevalidates() throws {
        let (container, vm) = try makeViewModel(playerCount: 8)
        try withExtendedLifetime(container) {
            vm.name = "Cup"
            vm.seeds = Array(vm.players.prefix(4))
            #expect(vm.canCreate)  // valid for size 4

            vm.size = .eight
            #expect(vm.seeds.count == 8)
            #expect(vm.canCreate == false)  // now needs 8

            vm.seeds = Array(vm.players.prefix(8))
            #expect(vm.canCreate)
        }
    }

    @Test func createGeneratesFullBracket() throws {
        let (container, vm) = try makeViewModel(playerCount: 4)
        try withExtendedLifetime(container) {
            vm.name = "Cup"
            vm.seeds = Array(vm.players.prefix(4))

            let tournament = vm.createTournament()
            #expect(tournament != nil)

            let expectedNodes = BracketGenerator.makePlan(size: .four).nodes.count
            #expect(tournament?.matches.count == expectedNodes)
            // Winners round 0 is seeded (no byes).
            let r0 = tournament?.matches.filter { $0.bracket == .winners && $0.round == 0 } ?? []
            #expect(r0.allSatisfy { $0.slot1PlayerId != nil && $0.slot2PlayerId != nil })
        }
    }
}
