import Foundation

/// App-wide authentication state. Restores the session on launch via `/me`,
/// persists the token via `TokenStore`, and exposes sign-in/out.
@MainActor
final class Session: ObservableObject {
    enum Phase: Equatable {
        case loading            // checking stored token on launch
        case signedIn(User)
        case signedOut
    }

    @Published private(set) var phase: Phase = .loading

    private let auth: AuthService
    private let tokenStore: TokenStore

    init(auth: AuthService, tokenStore: TokenStore) {
        self.auth = auth
        self.tokenStore = tokenStore
    }

    var currentUser: User? {
        if case .signedIn(let user) = phase { return user }
        return nil
    }

    /// Called once on launch: restore from a stored token, or land signed out.
    func restore() async {
        guard tokenStore.read() != nil else {
            phase = .signedOut
            return
        }
        do {
            phase = .signedIn(try await auth.me())
        } catch {
            tokenStore.clear()
            phase = .signedOut
        }
    }

    func register(email: String, password: String, displayName: String, handle: String) async throws {
        let result = try await auth.register(email: email, password: password, displayName: displayName, handle: handle)
        tokenStore.save(result.token)
        phase = .signedIn(result.user)
    }

    func login(email: String, password: String) async throws {
        let result = try await auth.login(email: email, password: password)
        tokenStore.save(result.token)
        phase = .signedIn(result.user)
    }

    func logout() {
        tokenStore.clear()
        phase = .signedOut
    }
}
