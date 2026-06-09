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
    let tournamentRepository: TournamentRepository

    /// Online match access (migration). Local repos above are retained until
    /// the online flow fully replaces them.
    let remoteMatches: RemoteMatchRepository

    private let context: ModelContext
    /// Live scoring view models, kept for the app session so re-entering a match
    /// preserves the in-progress frame state instead of starting over.
    private var liveMatchViewModels: [UUID: MatchViewModel] = [:]

    init(context: ModelContext, apiClient: APIClient) {
        self.context = context
        self.playerRepository = LocalPlayerRepository(context: context)
        self.matchRepository = LocalMatchRepository(context: context)
        self.tournamentRepository = LocalTournamentRepository(context: context)
        self.remoteMatches = RemoteMatchRepository(client: apiClient)
    }

    /// Returns the live view model for a match, reusing the cached instance.
    func liveMatchViewModel(for match: Match) -> MatchViewModel {
        if let existing = liveMatchViewModels[match.id] { return existing }
        let viewModel = MatchViewModel(match: match, context: context)
        // Completing any match advances the tournament it belongs to (if any),
        // so the bracket updates without a manual refresh.
        viewModel.onMatchCompleted = { [weak self] completed in
            try? self?.tournamentRepository.advanceOnCompletion(of: completed)
        }
        liveMatchViewModels[match.id] = viewModel
        return viewModel
    }

    /// Drops a cached view model (e.g. when its match is deleted).
    func releaseMatchViewModel(for matchId: UUID) {
        liveMatchViewModels[matchId] = nil
    }
}
