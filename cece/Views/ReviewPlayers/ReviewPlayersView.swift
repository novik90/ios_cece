import SwiftUI

struct ReviewPlayersView: View {
    @StateObject private var viewModel: ReviewPlayersViewModel
    let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: ReviewPlayersViewModel(repository: dependencies.playerRepository))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.players.isEmpty {
                    ContentUnavailableView(
                        "No players yet",
                        systemImage: "person.2",
                        description: Text("Add your first player to get started.")
                    )
                } else {
                    List {
                        ForEach(viewModel.players) { player in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.name).font(.body)
                                Text(player.createdAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: viewModel.delete)
                    }
                }
            }
            .navigationTitle("Players")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        NewPlayerView(dependencies: dependencies)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear { viewModel.load() }
        }
    }
}

#Preview {
    ReviewPlayersView(dependencies: PreviewData.dependencies)
}
