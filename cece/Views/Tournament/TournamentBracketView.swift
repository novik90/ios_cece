import SwiftUI

/// Scrollable double-elimination bracket: winners, losers, and grand final laid
/// out round by round. Reflects live state via the observed `Tournament` models;
/// tapping a ready match opens the launch screen (T7).
struct TournamentBracketView: View {
    let tournament: Tournament
    let dependencies: Dependencies

    @State private var namesById: [UUID: String] = [:]
    /// Drives the best-of sheet for a not-yet-started match.
    @State private var launchTarget: LaunchTarget?
    /// Match handed back by the sheet, pushed once the sheet has dismissed.
    @State private var pendingPush: Match?
    /// Match currently pushed onto the scoring screen.
    @State private var activeMatch: Match?

    /// Identifiable wrapper so a node can drive `.sheet(item:)`.
    private struct LaunchTarget: Identifiable {
        let id: UUID
        let node: TournamentMatch
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 28) {
                if let championId = tournament.championId {
                    championBanner(championId)
                }
                bracketSection("Верхняя сетка", .winners)
                bracketSection("Нижняя сетка", .losers)
                bracketSection("Гранд-финал", .grandFinal)
            }
            .padding(.vertical)
        }
        .background(Theme.Palette.background)
        .navigationTitle(tournament.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $launchTarget, onDismiss: {
            if let match = pendingPush {
                pendingPush = nil
                activeMatch = match
            }
        }) { target in
            TournamentMatchSetupView(node: target.node, dependencies: dependencies) { match in
                pendingPush = match
                launchTarget = nil
            }
        }
        .navigationDestination(item: $activeMatch) { match in
            MatchPlayView(viewModel: dependencies.liveMatchViewModel(for: match))
        }
        .onAppear(perform: loadNames)
    }

    /// Tapping a ready slot opens the best-of sheet; tapping an in-progress one
    /// resumes its match directly. Both routes push the scoring screen from the
    /// bracket, so "Back to matches" returns here.
    private func handleTap(_ node: TournamentMatch) {
        if let match = node.match {
            if match.completedAt == nil { activeMatch = match }
        } else if node.isReady {
            launchTarget = LaunchTarget(id: node.id, node: node)
        }
    }

    // MARK: Sections

    @ViewBuilder
    private func bracketSection(_ title: String, _ bracket: TournamentBracket) -> some View {
        let rounds = rounds(in: bracket)
        if !rounds.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .padding(.horizontal)

                HStack(alignment: .top, spacing: 20) {
                    ForEach(rounds, id: \.self) { round in
                        roundColumn(bracket, round)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func roundColumn(_ bracket: TournamentBracket, _ round: Int) -> some View {
        VStack(spacing: 14) {
            Text(roundTitle(bracket, round))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.Palette.textSecondary)

            ForEach(nodes(in: bracket, round: round), id: \.id) { node in
                BracketMatchCard(node: node, namesById: namesById) {
                    handleTap(node)
                }
            }
        }
    }

    private func championBanner(_ championId: UUID) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .foregroundStyle(Theme.Palette.teal)
            VStack(alignment: .leading, spacing: 2) {
                Text("Чемпион").font(.caption).foregroundStyle(Theme.Palette.textSecondary)
                Text(name(championId)).font(.headline).foregroundStyle(Theme.Palette.textPrimary)
            }
            Spacer()
        }
        .padding()
        .background(Theme.Palette.teal.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: Data

    private func rounds(in bracket: TournamentBracket) -> [Int] {
        Set(tournament.matches.filter { $0.bracket == bracket }.map(\.round)).sorted()
    }

    private func nodes(in bracket: TournamentBracket, round: Int) -> [TournamentMatch] {
        tournament.matches
            .filter { $0.bracket == bracket && $0.round == round }
            .sorted { $0.position < $1.position }
    }

    private func roundTitle(_ bracket: TournamentBracket, _ round: Int) -> String {
        if bracket == .grandFinal { return "Финал" }
        let isLast = round == (rounds(in: bracket).last ?? round)
        if isLast { return bracket == .winners ? "Финал ВС" : "Финал НС" }
        return "Раунд \(round + 1)"
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

#Preview {
    NavigationStack {
        TournamentBracketView(
            tournament: PreviewData.previewTournament,
            dependencies: PreviewData.dependencies
        )
    }
}
