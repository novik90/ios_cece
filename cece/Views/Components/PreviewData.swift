import Foundation
import SwiftData

/// In-memory SwiftData stack seeded with mock data for SwiftUI previews.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Player.self, Match.self, Frame.self, Break.self,
            configurations: config
        )

        let context = container.mainContext
        let ronnie = Player(name: "Ronnie O'Sullivan")
        let judd = Player(name: "Judd Trump")
        context.insert(ronnie)
        context.insert(judd)

        let match = Match(player1: ronnie, player2: judd, totalFrames: 5)
        context.insert(match)

        try? context.save()
        return container
    }()

    static var dependencies: Dependencies {
        Dependencies(context: container.mainContext)
    }
}
