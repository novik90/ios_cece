import SwiftUI

/// Searchable player chooser presented as a sheet. Shared by the match and
/// tournament creation flows; `excludedIds` hides players already chosen.
struct PlayerPickerSheet: View {
    let players: [Player]
    var excludedIds: Set<UUID> = []
    let onSelect: (Player) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [Player] {
        let available = players.filter { !excludedIds.contains($0.id) }
        guard !search.isEmpty else { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { player in
                Button {
                    onSelect(player)
                    dismiss()
                } label: {
                    HStack {
                        Text(player.name).foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
            }
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No players found",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different name.")
                    )
                }
            }
            .searchable(text: $search, prompt: "Search by name")
            .navigationTitle("Select player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
