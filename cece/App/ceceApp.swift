import SwiftUI
import SwiftData

@main
struct ceceApp: App {
    /// Shared SwiftData container for the whole app.
    let modelContainer: ModelContainer

    @StateObject private var dependencies: Dependencies

    init() {
        do {
            let container = try ModelContainer(
                for: Player.self, Match.self, Frame.self, Break.self
            )
            self.modelContainer = container
            _dependencies = StateObject(wrappedValue: Dependencies(context: container.mainContext))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(dependencies)
                .preferredColorScheme(.light)
        }
        .modelContainer(modelContainer)
    }
}
