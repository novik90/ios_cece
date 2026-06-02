import SwiftUI

/// Match-launch screen reached by tapping a ready bracket slot. Minimal
/// placeholder so T6 navigation works; best-of selection and actually starting
/// the match land in T7 (#20).
struct TournamentMatchSetupView: View {
    let node: TournamentMatch
    let dependencies: Dependencies

    @State private var namesById: [UUID: String] = [:]

    var body: some View {
        VStack(spacing: 16) {
            Text(name(node.slot1PlayerId))
            Text("vs").foregroundStyle(Theme.Palette.textSecondary)
            Text(name(node.slot2PlayerId))
        }
        .font(.title3.weight(.semibold))
        .foregroundStyle(Theme.Palette.textPrimary)
        .navigationTitle("Матч")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadNames)
    }

    private func name(_ id: UUID?) -> String {
        guard let id else { return "—" }
        return namesById[id] ?? "—"
    }

    private func loadNames() {
        guard namesById.isEmpty else { return }
        let players = (try? dependencies.playerRepository.fetchAll()) ?? []
        namesById = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0.name) })
    }
}
