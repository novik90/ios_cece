import Foundation

@MainActor
final class NewTournamentViewModel: ObservableObject {
    @Published private(set) var players: [Player] = []
    @Published var name: String = ""
    @Published var size: TournamentSize = .four {
        didSet { resizeSeeds() }
    }
    /// Seeded selections; index i holds seed i+1. Length always equals `size`.
    @Published var seeds: [Player?] = Array(repeating: nil, count: TournamentSize.four.rawValue)
    @Published var errorMessage: String?

    private let playerRepository: PlayerRepository
    private let tournamentRepository: TournamentRepository

    init(playerRepository: PlayerRepository, tournamentRepository: TournamentRepository) {
        self.playerRepository = playerRepository
        self.tournamentRepository = tournamentRepository
    }

    func loadPlayers() {
        do {
            players = try playerRepository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Stable seed indices for `ForEach` (avoids dynamic `0..<n` ranges).
    var seedIndices: [Int] { Array(0..<size.rawValue) }

    /// Ids already seeded, for excluding them in the picker.
    var selectedIds: Set<UUID> { Set(seeds.compactMap { $0?.id }) }

    /// Enough players exist to fill the chosen size.
    var hasEnoughPlayers: Bool { players.count >= size.rawValue }

    /// Roster must be complete (exactly N) and free of duplicates.
    var canCreate: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        let chosen = seeds.compactMap { $0 }
        guard chosen.count == size.rawValue else { return false }
        return Set(chosen.map(\.id)).count == chosen.count
    }

    /// Creates the tournament and generates its bracket. Returns it on success.
    func createTournament() -> Tournament? {
        guard canCreate else { return nil }
        let seeded = seeds.compactMap { $0 }
        do {
            return try tournamentRepository.create(
                name: name.trimmingCharacters(in: .whitespaces),
                size: size,
                players: seeded
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func resizeSeeds() {
        let n = size.rawValue
        if seeds.count < n {
            seeds.append(contentsOf: Array(repeating: nil, count: n - seeds.count))
        } else if seeds.count > n {
            seeds = Array(seeds.prefix(n))
        }
    }
}
