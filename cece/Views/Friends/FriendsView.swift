import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel: FriendsViewModel
    @State private var showAdd = false

    init(dependencies: Dependencies) {
        _viewModel = StateObject(wrappedValue: FriendsViewModel(repo: dependencies.remoteFriends))
    }

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.incoming.isEmpty {
                    Section("Requests") {
                        ForEach(viewModel.incoming) { request in
                            requestRow(request)
                        }
                    }
                }

                if !viewModel.outgoing.isEmpty {
                    Section("Sent") {
                        ForEach(viewModel.outgoing) { request in
                            userRow(request.user, caption: "Pending")
                        }
                    }
                }

                Section("Friends") {
                    if viewModel.friends.isEmpty {
                        Text("No friends yet. Tap + to add someone by handle.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.friends) { friend in
                            userRow(friend, caption: "@\(friend.handle)")
                                .swipeActions {
                                    Button("Remove", role: .destructive) {
                                        Task { await viewModel.remove(friend) }
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "person.badge.plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddFriendView(viewModel: viewModel)
            }
            .refreshable { await viewModel.loadAll() }
            .task { await viewModel.loadAll() }
        }
    }

    private func requestRow(_ request: API.FriendRequest) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(request.user.displayName).font(.body)
                Text("@\(request.user.handle)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Accept") { Task { await viewModel.accept(request) } }
                .buttonStyle(.borderedProminent)
            Button("Decline") { Task { await viewModel.decline(request) } }
                .buttonStyle(.bordered)
        }
        .buttonBorderShape(.capsule)
        .font(.caption)
    }

    private func userRow(_ user: API.PublicUser, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(user.displayName).font(.body)
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }
}
