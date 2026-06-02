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
            let other = slot == .one ? viewModel.player2 : viewModel.player1
            PlayerPickerSheet(
                players: viewModel.players,
                excludedIds: Set([other?.id].compactMap { $0 })
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

#Preview {
    NavigationStack {
        NewMatchView(dependencies: PreviewData.dependencies)
    }
}
