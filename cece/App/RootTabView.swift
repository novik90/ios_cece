import SwiftUI

/// Top-level tab navigation. Each tab hosts its own `NavigationStack`.
struct RootTabView: View {
    @EnvironmentObject private var dependencies: Dependencies

    var body: some View {
        TabView {
            HomeView(dependencies: dependencies)
                .tabItem { Label("Home", systemImage: "house") }

            MatchView()
                .tabItem { Label("Match", systemImage: "target") }

            NavigationStack {
                TournamentsListView(dependencies: dependencies)
            }
            .tabItem { Label("Tournaments", systemImage: "trophy") }

            NavigationStack {
                ReviewMatchesView(dependencies: dependencies)
            }
            .tabItem { Label("Stats", systemImage: "rectangle.split.2x1") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.Palette.teal)
    }
}

#Preview {
    RootTabView()
        .environmentObject(Dependencies(context: PreviewData.container.mainContext))
}
