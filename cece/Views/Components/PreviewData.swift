import Foundation
import SwiftData

/// In-memory SwiftData stack seeded with mock data for SwiftUI previews.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Player.self, Match.self, Frame.self, Break.self,
            Tournament.self, TournamentMatch.self,
            configurations: config
        )

        let context = container.mainContext
        let ronnie = Player(name: "Ronnie O'Sullivan")
        let judd = Player(name: "Judd Trump")
        context.insert(ronnie)
        context.insert(judd)

        let match = Match(player1: ronnie, player2: judd, totalFrames: 5)
        context.insert(match)

        // A seeded 4-player tournament for bracket previews.
        let fieldNames = ["Ronnie O'Sullivan", "Judd Trump", "Mark Selby", "Neil Robertson"]
        let field = fieldNames.map { Player(name: $0) }
        field.forEach { context.insert($0) }
        let tournament = Tournament(name: "Preview Cup", size: .four)
        context.insert(tournament)
        for node in BracketGenerator.makePlan(size: .four).makeMatches(players: field) {
            node.tournament = tournament
            context.insert(node)
        }

        try? context.save()
        return container
    }()

    static var dependencies: Dependencies {
        Dependencies(context: container.mainContext)
    }

    /// The seeded in-progress match, for `MatchView` previews.
    static var previewMatch: Match {
        let descriptor = FetchDescriptor<Match>()
        return (try? container.mainContext.fetch(descriptor))?.first
            ?? Match(player1: Player(name: "P1"), player2: Player(name: "P2"), totalFrames: 7)
    }

    /// The seeded 4-player tournament, for bracket previews.
    static var previewTournament: Tournament {
        let descriptor = FetchDescriptor<Tournament>()
        return (try? container.mainContext.fetch(descriptor))?.first
            ?? Tournament(name: "Preview Cup", size: .four)
    }

    /// A throwaway session (signed out), for previews that read `Session`.
    static var session: Session {
        Session(
            auth: RemoteAuthService(client: APIClient(tokenStore: InMemoryTokenStore())),
            tokenStore: InMemoryTokenStore()
        )
    }
}
