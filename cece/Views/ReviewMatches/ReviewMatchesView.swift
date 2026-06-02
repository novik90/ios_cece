import SwiftUI

struct ReviewMatchesView: View {
    @StateObject private var viewModel: ReviewMatchesViewModel
    @State private var pendingDelete: [Match]?
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: ReviewMatchesViewModel(repository: dependencies.matchRepository))
    }

    var body: some View {
        Group {
            if viewModel.matches.isEmpty {
                ContentUnavailableView(
                    "No matches played yet",
                    systemImage: "rectangle.split.2x1",
                    description: Text("Finished matches show up here.")
                )
            } else {
                List {
                    if !viewModel.tournamentMatches.isEmpty {
                        Section("Tournament matches") {
                            ForEach(viewModel.tournamentMatches) { match in
                                NavigationLink(value: match) { matchRow(match) }
                            }
                            .onDelete { offsets in
                                pendingDelete = offsets.map { viewModel.tournamentMatches[$0] }
                            }
                        }
                    }
                    if !viewModel.otherMatches.isEmpty {
                        Section("Other matches") {
                            ForEach(viewModel.otherMatches) { match in
                                NavigationLink(value: match) { matchRow(match) }
                            }
                            .onDelete { offsets in
                                pendingDelete = offsets.map { viewModel.otherMatches[$0] }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Statistics")
        .navigationDestination(for: Match.self) { match in
            MatchDetailView(match: match, dependencies: dependencies)
        }
        .confirmationDialog(
            "Delete match?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete match", role: .destructive) {
                if let toDelete = pendingDelete { viewModel.delete(toDelete) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("This permanently deletes the match and all its frames.")
        }
        .onAppear { viewModel.load() }
    }

    @ViewBuilder
    private func matchRow(_ match: Match) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if match.isTournamentMatch {
                Label(match.tournament?.name ?? "Tournament", systemImage: "trophy.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.Palette.teal)
            }
            HStack {
                Text(match.player1?.name ?? "—")
                Spacer()
                Text("\(match.framesWon(by: match.player1)) – \(match.framesWon(by: match.player2))")
                    .font(.headline)
                Spacer()
                Text(match.player2?.name ?? "—")
            }
            .font(.body)

            HStack(spacing: 8) {
                Text("Best of \(match.totalFrames)")
                Spacer()
                Text((match.completedAt ?? match.createdAt), style: .date)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        ReviewMatchesView(dependencies: PreviewData.dependencies)
    }
}
