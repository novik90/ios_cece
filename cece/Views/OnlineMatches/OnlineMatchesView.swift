import SwiftUI

/// The "Match" tab in the online flow: lists the signed-in user's matches and
/// creates new ones. Live scoring opens in block F (placeholder for now).
struct OnlineMatchesView: View {
    @EnvironmentObject private var session: Session
    @StateObject private var viewModel: OnlineMatchesViewModel
    @State private var showCreate = false
    @State private var showInvites = false
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: OnlineMatchesViewModel(repo: dependencies.remoteMatches))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.matches.isEmpty {
                    ContentUnavailableView(
                        "No matches yet",
                        systemImage: "target",
                        description: Text("Tap + to start a match.")
                    )
                } else {
                    List(viewModel.matches) { match in
                        NavigationLink(value: match) { matchRow(match) }
                    }
                }
            }
            .overlay { if viewModel.isLoading && viewModel.matches.isEmpty { ProgressView() } }
            .navigationTitle("Matches")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showInvites = true } label: { Image(systemName: "envelope") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showCreate = true } label: { Image(systemName: "plus") }
                }
            }
            .navigationDestination(for: API.MatchSummary.self) { match in
                OnlineMatchPlayView(
                    channel: dependencies.makeMatchChannel(matchId: match.id),
                    myUserId: session.currentUser?.id
                )
            }
            .sheet(isPresented: $showCreate) {
                NewOnlineMatchView(viewModel: viewModel) { Task { await viewModel.load() } }
            }
            .sheet(isPresented: $showInvites) {
                InvitesView(dependencies: dependencies)
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
        }
    }

    private func matchRow(_ match: API.MatchSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(match.participants.first?.displayName ?? "—")
                Spacer()
                Text("\(match.framesWon.first ?? 0) – \(match.framesWon.last ?? 0)").font(.headline)
                Spacer()
                Text(match.participants.last?.displayName ?? "—")
            }
            HStack {
                Text("Best of \(match.bestOf)")
                Spacer()
                Text(match.status.rawValue.capitalized)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MatchSummary needs Hashable to drive navigationDestination(for:).
// (Participant isn't Hashable, so hash by id; == is the synthesized Equatable.)
extension API.MatchSummary: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
