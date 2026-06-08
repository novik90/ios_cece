import SwiftUI

/// Placeholder for an opened match. Real-time scoring lands in block F (#66).
struct OnlineMatchPlaceholderView: View {
    let participants: [API.Participant]
    let status: API.MatchStatus

    var body: some View {
        VStack(spacing: 16) {
            Text("\(participants.first?.displayName ?? "—") vs \(participants.last?.displayName ?? "—")")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(status.rawValue.capitalized)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("Live scoring lands in the next update.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Match")
        .navigationBarTitleDisplayMode(.inline)
    }
}
