import SwiftUI
import SwiftData

@main
struct ceceApp: App {
    /// Shared SwiftData container for the whole app.
    let modelContainer: ModelContainer

    @StateObject private var dependencies: Dependencies
    @StateObject private var session: Session

    init() {
        do {
            let container = try ModelContainer(
                for: Player.self, Match.self, Frame.self, Break.self,
                Tournament.self, TournamentMatch.self
            )
            self.modelContainer = container

            // One APIClient + Keychain token, shared by auth and online repos.
            // A 401 logs the user out.
            let tokenStore = KeychainTokenStore()
            let client = APIClient(tokenStore: tokenStore)
            let authSession = Session(auth: RemoteAuthService(client: client), tokenStore: tokenStore)
            client.onUnauthorized = { [weak authSession] in authSession?.logout() }
            _session = StateObject(wrappedValue: authSession)
            _dependencies = StateObject(wrappedValue: Dependencies(context: container.mainContext, apiClient: client))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .environmentObject(session)
                .environmentObject(dependencies)
                .preferredColorScheme(.light)
        }
        .modelContainer(modelContainer)
    }
}
