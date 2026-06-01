import SwiftUI

/// Detailed career stats for one player. Styled with grouped sections to match
/// the rest of the app (Settings, etc.).
struct PlayerDetailView: View {
    let player: Player
    let stats: PlayerStats

    var body: some View {
        List {
            Section {
                header
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }

            Section("Record") {
                LabeledContent("Matches played", value: "\(stats.played)")
                LabeledContent("Wins", value: "\(stats.wins)")
                LabeledContent("Losses", value: "\(stats.losses)")
                LabeledContent("Win rate", value: String(format: "%.0f%%", stats.winPercentage))
            }

            Section("Top 10 breaks") {
                if stats.topBreaks.isEmpty {
                    Text("No breaks recorded yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(stats.topBreaks.enumerated()), id: \.element.id) { index, brk in
                        breakRow(rank: index + 1, brk: brk)
                    }
                }
            }
        }
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Break row

    private func breakRow(rank: Int, brk: BreakStat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("#\(rank)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text("\(brk.points)")
                    .font(.headline.monospacedDigit())
                Spacer()
                Text("vs \(brk.opponentName) · \(brk.matchDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            FlowLayout(spacing: 4) {
                ForEach(Array(brk.balls.enumerated()), id: \.offset) { _, ball in
                    BallDot(ball: ball, size: 20)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Theme.Palette.teal.opacity(0.15))
                .frame(width: 72, height: 72)
                .overlay {
                    Text(initials)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(Theme.Palette.teal)
                }
            Text(player.name)
                .font(.title2.weight(.bold))
            Text("\(stats.wins)W – \(stats.losses)L · \(String(format: "%.0f%%", stats.winPercentage)) win rate")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var initials: String {
        let parts = player.name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init)
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }
}

#Preview {
    NavigationStack {
        PlayerDetailView(
            player: Player(name: "Ronnie O'Sullivan"),
            stats: PlayerStats(player: Player(name: "Ronnie O'Sullivan"), matches: [])
        )
    }
}
