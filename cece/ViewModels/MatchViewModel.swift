import Foundation

/// Placeholder for the live scoring engine.
///
/// The full snooker rules engine (red→color alternation, color sequence after
/// reds, fouls, max break of 147, frame completion) will be implemented in a
/// later step. For now this is an intentional stub so the rest of the app can
/// compile and navigate.
@MainActor
final class MatchViewModel: ObservableObject {
    @Published var match: Match?

    private let repository: MatchRepository

    init(repository: MatchRepository, match: Match? = nil) {
        self.repository = repository
        self.match = match
    }

    // TODO: Implement scoring logic in Step 4.
}
