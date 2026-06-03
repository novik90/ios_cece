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
                    "No tournaments yet",
                    systemImage: "trophy",
                    description: Text("Create one with the + button in the top-right corner.")
                )
            } else {
                List {
                    if !viewModel.active.isEmpty {
                        Section("Active") {
                            ForEach(viewModel.active) { tournament in
                                row(tournament)
                                    .deleteSwipeAction { pendingDelete = tournament }
                            }
                        }
                    }
                    if !viewModel.completed.isEmpty {
                        Section("Completed") {
                            ForEach(viewModel.completed) { tournament in
                                row(tournament)
                                    .deleteSwipeAction { pendingDelete = tournament }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Tournaments")
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
            "Delete tournament?",
            item: $pendingDelete,
            message: "This permanently deletes the tournament and all its matches.",
            confirmLabel: "Delete",
            cancelLabel: "Cancel"
        ) { viewModel.delete($0) }
        .onAppear {
            viewModel.load()
            loadNames()
        }
    }

    private func row(_ tournament: Tournament) -> some View {
        NavigationLink(value: tournament) {
            ListRow(title: tournament.name, titleFont: .headline, caption: "\(tournament.size.rawValue) players") {
                status(tournament)
            }
        }
    }

    @ViewBuilder
    private func status(_ tournament: Tournament) -> some View {
        if let championId = tournament.championId {
            Label(namesById[championId] ?? "Champion", systemImage: "trophy.fill")
                .foregroundStyle(Theme.Palette.teal)
        } else {
            Text("In progress")
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
