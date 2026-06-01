import SwiftUI

struct NewMatchView: View {
    @StateObject private var viewModel: NewMatchViewModel
    @State private var createdMatch: Match?
    @State private var pickingSlot: PlayerSlot?
    private let dependencies: Dependencies

    /// Which player is being chosen.
    private enum PlayerSlot: Int, Identifiable {
        case one, two
        var id: Int { rawValue }
    }

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: NewMatchViewModel(
            playerRepository: dependencies.playerRepository,
            matchRepository: dependencies.matchRepository
        ))
    }

    var body: some View {
        Form {
            if viewModel.players.count < 2 {
                Section {
                    Text("You need at least two players. Add players from the home screen first.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Players") {
                    playerRow(title: "Player 1", player: viewModel.player1, slot: .one)
                    playerRow(title: "Player 2", player: viewModel.player2, slot: .two)
                }

                Section("Format") {
                    Picker("Best of", selection: $viewModel.totalFrames) {
                        ForEach(viewModel.frameOptions, id: \.self) { n in
                            Text("Best of \(n)").tag(n)
                        }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("New match")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    // On success, push straight into the live scoring screen for
                    // the match we just created.
                    createdMatch = viewModel.createMatch()
                }
                .disabled(!viewModel.canCreate)
            }
        }
        .navigationDestination(item: $createdMatch) { match in
            MatchPlayView(viewModel: dependencies.liveMatchViewModel(for: match))
        }
        .sheet(item: $pickingSlot) { slot in
            PlayerPickerSheet(
                players: viewModel.players,
                excluded: slot == .one ? viewModel.player2 : viewModel.player1
            ) { picked in
                switch slot {
                case .one: viewModel.player1 = picked
                case .two: viewModel.player2 = picked
                }
            }
        }
        .onAppear { viewModel.loadPlayers() }
    }

    private func playerRow(title: String, player: Player?, slot: PlayerSlot) -> some View {
        Button {
            pickingSlot = slot
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Text(player?.name ?? "Select")
                    .foregroundStyle(player == nil ? .secondary : Theme.Palette.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// Searchable player chooser presented as a sheet.
private struct PlayerPickerSheet: View {
    let players: [Player]
    let excluded: Player?
    let onSelect: (Player) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [Player] {
        let available = players.filter { $0.id != excluded?.id }
        guard !search.isEmpty else { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { player in
                Button {
                    onSelect(player)
                    dismiss()
                } label: {
                    HStack {
                        Text(player.name).foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
            }
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No players found",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different name.")
                    )
                }
            }
            .searchable(text: $search, prompt: "Search by name")
            .navigationTitle("Select player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        NewMatchView(dependencies: PreviewData.dependencies)
    }
}
