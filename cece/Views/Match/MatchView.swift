import SwiftUI

/// Placeholder live-scoring screen. The interactive scoring UI and rules engine
/// arrive in a later step (see `MatchViewModel`).
struct MatchView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.Palette.teal)
                    Text("Match")
                        .font(.title2).fontWeight(.bold)
                    Text("Live scoring coming soon.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Match")
        }
    }
}

#Preview {
    MatchView()
}
