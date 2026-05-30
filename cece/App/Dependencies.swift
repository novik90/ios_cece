import Foundation
import SwiftData

/// Composition root. Holds the concrete repositories built from the SwiftData
/// context and hands them to view models. Swapping `LocalXRepository` for a
/// future `NetworkXRepository` happens only here — no view or view model needs
/// to change.
@MainActor
final class Dependencies: ObservableObject {
    let playerRepository: PlayerRepository
    let matchRepository: MatchRepository

    init(context: ModelContext) {
        self.playerRepository = LocalPlayerRepository(context: context)
        self.matchRepository = LocalMatchRepository(context: context)
    }
}
