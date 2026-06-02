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
                            ForEach(viewModel.active) { row($0) }
                        }
                    }
                    if !viewModel.completed.isEmpty {
                        Section("Завершённые") {
                            ForEach(viewModel.completed) { row($0) }
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
        .confirmationDialog(
            "Удалить турнир?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                if let tournament = pendingDelete { viewModel.delete(tournament) }
                pendingDelete = nil
            }
            Button("Отмена", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Турнир и все его матчи будут удалены безвозвратно.")
        }
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
        .swipeActions {
            Button("Удалить", role: .destructive) { pendingDelete = tournament }
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
