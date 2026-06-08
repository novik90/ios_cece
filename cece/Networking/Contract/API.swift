import Foundation

/// Namespace for backend wire models (mirrors `packages/contract`).
///
/// Kept under `API.` so the new online types coexist with the legacy local
/// SwiftData models (`Match`, `Break`, …) during the migration. The auth
/// identity `User` lives at top level (introduced with auth).
enum API {
    /// Participant index within a match: `0` or `1`.
    typealias Slot = Int
}
