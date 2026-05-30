import SwiftUI

struct NewMatchView: View {
    @StateObject private var viewModel: NewMatchViewModel
    @Environment(\.dismiss) private var dismiss

    init(dependencies: Dependencies) {
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
                    Picker("Player 1", selection: $viewModel.player1) {
                        Text("Select").tag(Player?.none)
                        ForEach(viewModel.players) { player in
                            Text(player.name).tag(Player?.some(player))
                        }
                    }
                    Picker("Player 2", selection: $viewModel.player2) {
                        Text("Select").tag(Player?.none)
                        ForEach(viewModel.players) { player in
                            Text(player.name).tag(Player?.some(player))
                        }
                    }
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
                    if viewModel.createMatch() != nil { dismiss() }
                }
                .disabled(!viewModel.canCreate)
            }
        }
        .onAppear { viewModel.loadPlayers() }
    }
}

#Preview {
    NavigationStack {
        NewMatchView(dependencies: PreviewData.dependencies)
    }
}
