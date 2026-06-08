import SwiftUI

/// Detailed breakdown of a completed match. Grouped sections match the app's
/// other detail screens. Tapping a player opens their career detail.
struct MatchDetailView: View {
    @StateObject private var viewModel: MatchDetailViewModel

    init(match: Match, dependencies: Dependencies) {
        _viewModel = StateObject(wrappedValue: MatchDetailViewModel(
            match: match,
            repository: dependencies.matchRepository,
            tournamentRepository: dependencies.tournamentRepository
        ))
    }

    var body: some View {
        List {
            Section {
                header
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }

            Section("Result") {
                if let winner = viewModel.winner {
                    playerRow(player: winner, role: "Winner", icon: "trophy.fill", tint: Theme.Palette.teal)
                }
                if let loser = viewModel.loser {
                    playerRow(player: loser, role: "Runner-up", icon: "person.fill", tint: Theme.Palette.textSecondary)
                }
                LabeledContent("Frames") {
                    Text("\(viewModel.framesWon(by: viewModel.winner)) – \(viewModel.framesWon(by: viewModel.loser))")
                        .font(.body.monospacedDigit())
                }
            }

            Section("Details") {
                if FeatureFlags.tournamentsEnabled, viewModel.match.isTournamentMatch {
                    LabeledContent("Tournament", value: viewModel.match.tournament?.name ?? "—")
                }
                LabeledContent("Date", value: viewModel.date.formatted(date: .abbreviated, time: .shortened))
                if let duration = viewModel.duration {
                    LabeledContent("Duration", value: formatDuration(duration))
                }
                LabeledContent("Best of", value: "\(viewModel.match.totalFrames)")
                LabeledContent("Head-to-head") { Text("\(viewModel.headToHeadCount) matches") }
            }

            Section("Frames") {
                ForEach(viewModel.frames) { frame in
                    frameRow(frame)
                }
            }

            Section("Top breaks") {
                if viewModel.topBreaks.isEmpty {
                    Text("No breaks over one ball.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(viewModel.topBreaks.enumerated()), id: \.element.id) { index, brk in
                        breakRow(rank: index + 1, brk: brk)
                    }
                }
            }
        }
        .navigationTitle("Match")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Player.self) { player in
            PlayerDetailView(player: player, stats: viewModel.stats(for: player))
        }
        .onAppear { viewModel.load() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Palette.teal)
            Group {
                if let winner = viewModel.winner {
                    Text("\(winner.name) won")
                } else {
                    Text("Match complete")
                }
            }
            .font(.title2.weight(.bold))
            .multilineTextAlignment(.center)
            Text("\(viewModel.framesWon(by: viewModel.winner)) – \(viewModel.framesWon(by: viewModel.loser))")
                .font(.largeTitle.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Rows

    private func playerRow(player: Player, role: LocalizedStringKey, icon: String, tint: Color) -> some View {
        NavigationLink(value: player) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.name).font(.body)
                    Text(role).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func frameRow(_ frame: Frame) -> some View {
        HStack {
            Text("Frame \(frame.frameNumber)")
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(frame.player1Score) – \(frame.player2Score)")
                .font(.body.monospacedDigit())
                .fontWeight(.semibold)
        }
    }

    private func breakRow(rank: Int, brk: MatchDetailViewModel.MatchBreak) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("#\(rank)")
                    .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                Text("\(brk.points)")
                    .font(.headline.monospacedDigit())
                Spacer()
                Text("by \(brk.playerName)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            FlowLayout(spacing: 4) {
                ForEach(Array(brk.balls.enumerated()), id: \.offset) { _, ball in
                    BallDot(ball: ball, size: 20)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func formatDuration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval < 3600 ? [.minute, .second] : [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? "—"
    }
}
