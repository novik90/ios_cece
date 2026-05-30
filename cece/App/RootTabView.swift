import SwiftUI

/// Top-level tab navigation. Each tab hosts its own `NavigationStack`.
struct RootTabView: View {
    @EnvironmentObject private var dependencies: Dependencies

    var body: some View {
        TabView {
            HomeView(dependencies: dependencies)
                .tabItem { Label("Главная", systemImage: "house") }

            MatchView()
                .tabItem { Label("Матч", systemImage: "target") }

            ReviewMatchesView(dependencies: dependencies)
                .tabItem { Label("Стат.", systemImage: "rectangle.split.2x1") }

            SettingsView()
                .tabItem { Label("Настр.", systemImage: "gearshape") }
        }
        .tint(Theme.Palette.teal)
    }
}

#Preview {
    RootTabView()
        .environmentObject(Dependencies(context: PreviewData.container.mainContext))
}
