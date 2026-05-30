import SwiftUI

struct ReviewMatchesView: View {
    @StateObject private var viewModel: ReviewMatchesViewModel

    init(dependencies: Dependencies) {
        _viewModel = StateObject(wrappedValue: ReviewMatchesViewModel(repository: dependencies.matchRepository))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.matches.isEmpty {
                    ContentUnavailableView(
                        "No matches yet",
                        systemImage: "rectangle.split.2x1",
                        description: Text("Start a new match to see it here.")
                    )
                } else {
                    List {
                        ForEach(viewModel.matches) { match in
                            matchRow(match)
                        }
                        .onDelete(perform: viewModel.delete)
                    }
                }
            }
            .navigationTitle("Matches")
            .onAppear { viewModel.load() }
        }
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
                Text("•")
                Text(match.isCompleted ? "Completed" : "In progress")
                Spacer()
                Text(match.createdAt, style: .date)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ReviewMatchesView(dependencies: PreviewData.dependencies)
}
