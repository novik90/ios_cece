import Foundation

/// Compile-time feature switches.
enum FeatureFlags {
    /// Tournaments are hidden while the remote backend has no tournaments yet
    /// (migration epic #58, block J). The local tournament implementation is
    /// kept in the project and returns when the backend gains tournaments —
    /// flip this back to `true`.
    static let tournamentsEnabled = false
}
