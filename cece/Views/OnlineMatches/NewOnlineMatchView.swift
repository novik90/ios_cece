import SwiftUI

/// Create an online match. Block E supports a guest opponent; playing a
/// registered user (by friendship) arrives with block G.
struct NewOnlineMatchView: View {
    @ObservedObject var viewModel: OnlineMatchesViewModel
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var guestName = ""
    @State private var bestOf = 5
    @State private var isBusy = false

    private let frameOptions = [1, 3, 5, 7, 9, 11, 15, 19, 35]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Guest name", text: $guestName)
                } header: {
                    Text("Opponent")
                } footer: {
                    Text("Playing a registered friend comes with the friends update.")
                }

                Section("Format") {
                    Picker("Best of", selection: $bestOf) {
                        ForEach(frameOptions, id: \.self) { Text("Best of \($0)").tag($0) }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Theme.Palette.error) }
                }
            }
            .navigationTitle("New match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(!canCreate || isBusy)
                }
            }
        }
    }

    private var canCreate: Bool {
        !guestName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func create() async {
        isBusy = true
        defer { isBusy = false }
        if await viewModel.createGuestMatch(name: guestName.trimmingCharacters(in: .whitespaces), bestOf: bestOf) != nil {
            onCreated()
            dismiss()
        }
    }
}
