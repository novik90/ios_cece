import SwiftUI

/// Match invitations: received (accept/decline) and sent (cancel). Accepting
/// creates a match (it then appears in the Matches list).
struct InvitesView: View {
    @StateObject private var viewModel: InvitesViewModel
    @State private var showNew = false
    @State private var notice: String?
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: InvitesViewModel(repo: dependencies.remoteInvites))
    }

    var body: some View {
        NavigationStack {
            List {
                if let notice {
                    Section { Text(notice).foregroundStyle(Theme.Palette.teal) }
                }
                if let errorMessage = viewModel.errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Theme.Palette.error) }
                }

                Section("Received") {
                    if viewModel.incoming.isEmpty {
                        Text("No invitations.").foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.incoming) { invite in receivedRow(invite) }
                    }
                }

                if !viewModel.outgoing.isEmpty {
                    Section("Sent") {
                        ForEach(viewModel.outgoing) { invite in sentRow(invite) }
                    }
                }
            }
            .navigationTitle("Invites")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showNew) {
                NewInviteView(dependencies: dependencies, viewModel: viewModel)
            }
            .refreshable { await viewModel.loadAll() }
            .task { await viewModel.loadAll() }
        }
    }

    private func receivedRow(_ invite: API.MatchInvite) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            inviteSummary(name: invite.from.displayName, invite: invite)
            if invite.status == .pending {
                HStack {
                    Button("Accept") {
                        Task {
                            if (await viewModel.accept(invite)) != nil { notice = "Match created — see the Match tab." }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Decline") { Task { await viewModel.decline(invite) } }
                        .buttonStyle(.bordered)
                }
                .buttonBorderShape(.capsule)
                .font(.caption)
            }
        }
    }

    private func sentRow(_ invite: API.MatchInvite) -> some View {
        HStack {
            inviteSummary(name: invite.to.displayName, invite: invite)
            Spacer()
            if invite.status == .pending {
                Button("Cancel", role: .destructive) { Task { await viewModel.cancel(invite) } }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .font(.caption)
            }
        }
    }

    private func inviteSummary(name: String, invite: API.MatchInvite) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(name).font(.body)
            Text("Best of \(invite.bestOf) · \(invite.status.rawValue.capitalized)")
                .font(.caption)
                .foregroundStyle(invite.status == .expired ? Theme.Palette.error : Color.secondary)
        }
    }
}
