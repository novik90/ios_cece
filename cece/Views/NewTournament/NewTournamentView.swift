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
                    Text("Нужно минимум \(viewModel.size.rawValue) игроков. Добавьте игроков на главном экране.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Турнир") {
                TextField("Название", text: $viewModel.name)
            }

            Section("Размер") {
                Picker("Игроков", selection: $viewModel.size) {
                    ForEach(TournamentSize.allCases, id: \.self) { size in
                        Text("\(size.rawValue)").tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Посев") {
                ForEach(viewModel.seedIndices, id: \.self) { index in
                    seedRow(index: index)
                }
            }

            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundStyle(Theme.Palette.error) }
            }
        }
        .navigationTitle("Новый турнир")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Создать") {
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
        Button {
            pickingSeed = SeedSlot(id: index)
        } label: {
            HStack {
                Text("Сид \(index + 1)")
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Text(viewModel.seeds[index]?.name ?? "Выбрать")
                    .foregroundStyle(viewModel.seeds[index] == nil ? .secondary : Theme.Palette.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NewTournamentView(dependencies: PreviewData.dependencies)
    }
}
