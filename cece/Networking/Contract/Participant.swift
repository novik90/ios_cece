import Foundation

extension API {
    /// Public projection of a user (contract v1: `{ id, handle, displayName }`).
    struct PublicUser: Codable, Identifiable, Equatable {
        let id: String
        let handle: String
        let displayName: String
    }

    /// A match participant — a registered user or a nameless guest.
    /// Wire shape is a discriminated union keyed by `kind`.
    enum Participant: Codable, Equatable {
        case user(id: String, handle: String, displayName: String)
        case guest(name: String)

        /// Name to show in the UI. Guests fall back to their entered name.
        var displayName: String {
            switch self {
            case let .user(_, _, displayName): return displayName
            case let .guest(name): return name
            }
        }

        var isGuest: Bool {
            if case .guest = self { return true }
            return false
        }

        var userId: String? {
            if case let .user(id, _, _) = self { return id }
            return nil
        }

        private enum CodingKeys: String, CodingKey {
            case kind, userId, handle, displayName, name
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(String.self, forKey: .kind) {
            case "user":
                self = .user(
                    id: try container.decode(String.self, forKey: .userId),
                    handle: try container.decode(String.self, forKey: .handle),
                    displayName: try container.decode(String.self, forKey: .displayName)
                )
            case "guest":
                self = .guest(name: try container.decode(String.self, forKey: .name))
            case let other:
                throw DecodingError.dataCorruptedError(
                    forKey: .kind, in: container, debugDescription: "Unknown participant kind: \(other)"
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .user(id, handle, displayName):
                try container.encode("user", forKey: .kind)
                try container.encode(id, forKey: .userId)
                try container.encode(handle, forKey: .handle)
                try container.encode(displayName, forKey: .displayName)
            case let .guest(name):
                try container.encode("guest", forKey: .kind)
                try container.encode(name, forKey: .name)
            }
        }
    }
}
