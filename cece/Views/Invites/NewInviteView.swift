import SwiftUI

/// Invite any user to a match (friendship not required). Search by handle, pick
/// the format, send.
struct NewInviteView: View {
    let dependencies: Dependencies
    @ObservedObject var viewModel: InvitesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [API.PublicUser] = []
    @State private var selected: API.PublicUser?
    @State private var bestOf = 5
    @State private var selfScoringDisabled = false
    @State private var isBusy = false

    private let frameOptions = [1, 3, 5, 7, 9, 11, 15, 19, 35]

    var body: some View {
        NavigationStack {
            Form {
                Section("Opponent") {
                    if let selected {
                        HStack {
                            Text(selected.displayName)
                            Spacer()
                            Button("Change") { self.selected = nil }
                                .font(.caption)
                        }
                    } else {
                        ForEach(results) { user in
                            Button {
                                selected = user
                                query = ""
                                results = []
                            } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(user.displayName).foregroundStyle(Theme.Palette.textPrimary)
                                    Text("@\(user.handle)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if selected != nil {
                    Section("Format") {
                        Picker("Best of", selection: $bestOf) {
                            ForEach(frameOptions, id: \.self) { Text("Best of \($0)").tag($0) }
                        }
                        Toggle("Score for the player at the table", isOn: $selfScoringDisabled)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Theme.Palette.error) }
                }
            }
            .searchable(text: $query, prompt: "Search opponent by handle")
            .task(id: query) { await runSearch() }
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await send() } }
                        .disabled(selected == nil || isBusy)
                }
            }
        }
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard selected == nil, trimmed.count >= 2 else { results = []; return }
        results = (try? await dependencies.remoteFriends.searchUsers(handle: trimmed)) ?? []
    }

    private func send() async {
        guard let selected else { return }
        isBusy = true
        defer { isBusy = false }
        if await viewModel.create(
            userId: selected.id,
            bestOf: bestOf,
            selfScoringDisabled: selfScoringDisabled
        ) != nil {
            dismiss()
        }
    }
}
