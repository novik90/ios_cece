import SwiftUI

/// Search users by handle and send a friend request.
struct AddFriendView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [API.PublicUser] = []
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            List {
                if let notice {
                    Section { Text(notice).foregroundStyle(Theme.Palette.teal) }
                }
                ForEach(results) { user in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(user.displayName)
                            Text("@\(user.handle)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Add") { Task { await add(user) } }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .font(.caption)
                    }
                }
            }
            .overlay {
                if results.isEmpty && query.count >= 2 {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: "Search by handle")
            .navigationTitle("Add friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task(id: query) { await runSearch() }
        }
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.count >= 2 else { results = []; return }
        results = await viewModel.search(handle: trimmed)
    }

    private func add(_ user: API.PublicUser) async {
        guard let result = await viewModel.send(userId: user.id) else { return }
        switch result {
        case .befriended(let friend): notice = "You're now friends with \(friend.displayName)."
        case .requested: notice = "Request sent."
        }
        results.removeAll { $0.id == user.id }
    }
}
