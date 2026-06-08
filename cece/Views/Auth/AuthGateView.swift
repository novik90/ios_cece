import SwiftUI

/// App root: restores the session on launch and routes to the app or the auth
/// flow. The app is fully behind authentication (online-only, registration
/// required).
struct AuthGateView: View {
    @EnvironmentObject private var session: Session

    var body: some View {
        Group {
            switch session.phase {
            case .loading:
                ProgressView().controlSize(.large)
            case .signedIn:
                RootTabView()
            case .signedOut:
                NavigationStack { LoginView() }
            }
        }
        .task {
            if case .loading = session.phase { await session.restore() }
        }
    }
}
