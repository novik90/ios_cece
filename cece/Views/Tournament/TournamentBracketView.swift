import SwiftUI

/// Bracket screen. This is a minimal, navigable placeholder so the creation
/// flow (T5) has a destination; the full bracket visualization lands in T6 (#19).
struct TournamentBracketView: View {
    let tournament: Tournament
    let dependencies: Dependencies

    @State private var namesById: [UUID: String] = [:]

    private let brackets: [TournamentBracket] = [.winners, .losers, .grandFinal]

    var body: some View {
        List {
            ForEach(brackets, id: \.self) { bracket in
                section(for: bracket)
            }
        }
        .navigationTitle(tournament.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadNames)
    }

    @ViewBuilder
    private func section(for bracket: TournamentBracket) -> some View {
        let nodes = nodes(in: bracket)
        if !nodes.isEmpty {
            Section(title(for: bracket)) {
                ForEach(nodes, id: \.id) { node in
                    nodeRow(node)
                }
            }
        }
    }

    private func nodes(in bracket: TournamentBracket) -> [TournamentMatch] {
        tournament.matches
            .filter { $0.bracket == bracket }
            .sorted { ($0.round, $0.position) < ($1.round, $1.position) }
    }

    private func nodeRow(_ node: TournamentMatch) -> some View {
        HStack {
            Text("R\(node.round + 1)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 36, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(slotName(node.slot1PlayerId))
                Text(slotName(node.slot2PlayerId))
            }
            .foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
        }
    }

    private func slotName(_ id: UUID?) -> String {
        guard let id else { return "—" }
        return namesById[id] ?? "—"
    }

    private func title(for bracket: TournamentBracket) -> String {
        switch bracket {
        case .winners: return "Верхняя сетка"
        case .losers: return "Нижняя сетка"
        case .grandFinal: return "Гранд-финал"
        }
    }

    private func loadNames() {
        guard namesById.isEmpty else { return }
        let players = (try? dependencies.playerRepository.fetchAll()) ?? []
        namesById = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0.name) })
    }
}

#Preview {
    NavigationStack {
        TournamentBracketView(
            tournament: PreviewData.previewTournament,
            dependencies: PreviewData.dependencies
        )
    }
}
