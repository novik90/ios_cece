import SwiftUI

struct ReviewMatchesView: View {
    @StateObject private var viewModel: ReviewMatchesViewModel
    @State private var pendingDelete: IndexSet?
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
                    ForEach(viewModel.matches) { match in
                        NavigationLink(value: match) {
                            matchRow(match)
                        }
                    }
                    .onDelete { pendingDelete = $0 }
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
                if let offsets = pendingDelete { viewModel.delete(at: offsets) }
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
