import SwiftUI

struct NewTournamentView: View {
    @StateObject private var viewModel: NewTournamentViewModel
    @State private var createdTournament: Tournament?
    @State private var pickingSeed: SeedSlot?
    private let dependencies: Dependencies

    /// Identifiable wrapper so a seed index can drive `.sheet(item:)`.
    private struct SeedSlot: Identifiable { let id: Int }

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: NewTournamentViewModel(
            playerRepository: dependencies.playerRepository,
            tournamentRepository: dependencies.tournamentRepository
        ))
    }

    var body: some View {
        Form {
            if !viewModel.hasEnoughPlayers {
                Section {
                    Text("You need at least \(viewModel.size.rawValue) players. Add players from the home screen first.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Tournament") {
                TextField("Name", text: $viewModel.name)
            }

            Section("Size") {
                Picker("Players", selection: $viewModel.size) {
                    ForEach(TournamentSize.allCases, id: \.self) { size in
                        Text("\(size.rawValue)").tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Seeding") {
                ForEach(viewModel.seedIndices, id: \.self) { index in
                    seedRow(index: index)
                }
            }

            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundStyle(Theme.Palette.error) }
            }
        }
        .navigationTitle("New tournament")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    createdTournament = viewModel.createTournament()
                }
                .disabled(!viewModel.canCreate)
            }
        }
        .navigationDestination(item: $createdTournament) { tournament in
            TournamentBracketView(tournament: tournament, dependencies: dependencies)
        }
        .sheet(item: $pickingSeed) { slot in
            PlayerPickerSheet(
                players: viewModel.players,
                excludedIds: viewModel.selectedIds.subtracting(
                    [viewModel.seeds[slot.id]?.id].compactMap { $0 }
                )
            ) { picked in
                viewModel.seeds[slot.id] = picked
            }
        }
        .onAppear { viewModel.loadPlayers() }
    }

    private func seedRow(index: Int) -> some View {
        SelectRow(title: "Seed \(index + 1)", value: viewModel.seeds[index]?.name, placeholder: "Select") {
            pickingSeed = SeedSlot(id: index)
        }
    }
}

#Preview {
    NavigationStack {
        NewTournamentView(dependencies: PreviewData.dependencies)
    }
}
