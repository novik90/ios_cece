import Foundation
import Security

/// Abstraction over access-token persistence.
protocol TokenStore: AnyObject {
    func save(_ token: String)
    func read() -> String?
    func clear()
}

/// Keychain-backed access token storage (one access JWT; refresh tokens are not
/// used — see the migration plan).
final class KeychainTokenStore: TokenStore {
    private let service = "com.cece.snooker.auth"
    private let account = "accessToken"

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func save(_ token: String) {
        SecItemDelete(baseQuery as CFDictionary)
        var attrs = baseQuery
        attrs[kSecValueData as String] = Data(token.utf8)
        SecItemAdd(attrs as CFDictionary, nil)
    }

    func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8)
        else { return nil }
        return token
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

/// In-memory token store, for tests and previews.
final class InMemoryTokenStore: TokenStore {
    private var token: String?
    init(_ token: String? = nil) { self.token = token }
    func save(_ token: String) { self.token = token }
    func read() -> String? { token }
    func clear() { token = nil }
}
