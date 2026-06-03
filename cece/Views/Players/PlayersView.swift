import SwiftUI

/// Players overview: every player with a quick record caption. Tapping a player
/// pushes their detailed stats. Designed to be hosted inside an existing
/// `NavigationStack` (it is pushed from the home screen).
struct PlayersView: View {
    @StateObject private var viewModel: PlayersViewModel
    @State private var pendingDelete: IndexSet?

    init(dependencies: Dependencies) {
        _viewModel = StateObject(wrappedValue: PlayersViewModel(
            playerRepository: dependencies.playerRepository,
            matchRepository: dependencies.matchRepository,
            tournamentRepository: dependencies.tournamentRepository
        ))
    }

    var body: some View {
        Group {
            if viewModel.players.isEmpty {
                ContentUnavailableView(
                    "No players yet",
                    systemImage: "person.2",
                    description: Text("Add players from the home screen to get started.")
                )
            } else {
                List {
                    ForEach(viewModel.players) { player in
                        NavigationLink(value: player) {
                            row(for: player)
                        }
                    }
                    .onDelete { pendingDelete = $0 }
                }
            }
        }
        .navigationTitle("Players")
        .navigationDestination(for: Player.self) { player in
            PlayerDetailView(player: player, stats: viewModel.stats(for: player))
        }
        .deleteConfirmation(
            "Delete player?",
            item: $pendingDelete,
            message: "This permanently deletes the player. Their past matches stay but will show no name.",
            confirmLabel: "Delete player"
        ) { viewModel.delete(at: $0) }
        .onAppear { viewModel.load() }
    }

    private func row(for player: Player) -> some View {
        let stats = viewModel.stats(for: player)
        return VStack(alignment: .leading, spacing: 3) {
            Text(player.name)
                .font(.body)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("\(stats.played) played · \(stats.wins) wins · \(stats.losses) losses")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        PlayersView(dependencies: PreviewData.dependencies)
    }
}
