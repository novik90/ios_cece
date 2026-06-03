import SwiftUI

/// Entry point for tournaments: lists active and completed tournaments, with
/// create, open-bracket, and delete.
struct TournamentsListView: View {
    @StateObject private var viewModel: TournamentsViewModel
    @State private var pendingDelete: Tournament?
    @State private var namesById: [UUID: String] = [:]
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: TournamentsViewModel(
            repository: dependencies.tournamentRepository
        ))
    }

    var body: some View {
        Group {
            if viewModel.tournaments.isEmpty {
                ContentUnavailableView(
                    "Пока нет турниров",
                    systemImage: "trophy",
                    description: Text("Создайте турнир кнопкой + в правом верхнем углу.")
                )
            } else {
                List {
                    if !viewModel.active.isEmpty {
                        Section("Активные") {
                            ForEach(viewModel.active) { tournament in
                                row(tournament)
                                    .deleteSwipeAction { pendingDelete = tournament }
                            }
                        }
                    }
                    if !viewModel.completed.isEmpty {
                        Section("Завершённые") {
                            ForEach(viewModel.completed) { tournament in
                                row(tournament)
                                    .deleteSwipeAction { pendingDelete = tournament }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Турниры")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    NewTournamentView(dependencies: dependencies)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(for: Tournament.self) { tournament in
            TournamentBracketView(tournament: tournament, dependencies: dependencies)
        }
        .deleteConfirmation(
            "Удалить турнир?",
            item: $pendingDelete,
            message: "Турнир и все его матчи будут удалены безвозвратно.",
            confirmLabel: "Удалить",
            cancelLabel: "Отмена"
        ) { viewModel.delete($0) }
        .onAppear {
            viewModel.load()
            loadNames()
        }
    }

    private func row(_ tournament: Tournament) -> some View {
        NavigationLink(value: tournament) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tournament.name)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                HStack {
                    Text("\(tournament.size.rawValue) игроков")
                    Spacer()
                    status(tournament)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func status(_ tournament: Tournament) -> some View {
        if let championId = tournament.championId {
            Label(namesById[championId] ?? "Чемпион", systemImage: "trophy.fill")
                .foregroundStyle(Theme.Palette.teal)
        } else {
            Text("В процессе")
        }
    }

    private func loadNames() {
        let players = (try? dependencies.playerRepository.fetchAll()) ?? []
        namesById = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0.name) })
    }
}

#Preview {
    NavigationStack {
        TournamentsListView(dependencies: PreviewData.dependencies)
    }
}
