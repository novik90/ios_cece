import Foundation

extension BracketPlan {
    /// Materializes the plan into `TournamentMatch` nodes, seating `players`
    /// (ordered so `players[i]` is seed i+1) into the winners round-0 slots and
    /// wiring winner/loser destinations by the freshly assigned node ids.
    ///
    /// The returned nodes are not yet inserted into a context; the caller
    /// attaches them to a `Tournament` and saves.
    @MainActor
    func makeMatches(players: [Player]) -> [TournamentMatch] {
        precondition(players.count == size, "expected \(size) players, got \(players.count)")

        // One TournamentMatch per plan node, index-aligned with `nodes`.
        let matches = nodes.map { node in
            TournamentMatch(bracket: node.bracket, round: node.round, position: node.position)
        }

        for node in nodes {
            if let seed = node.seed1 { matches[node.index].slot1PlayerId = players[seed - 1].id }
            if let seed = node.seed2 { matches[node.index].slot2PlayerId = players[seed - 1].id }

            if let edge = node.winnerTo {
                matches[node.index].winnerDestinationId = matches[edge.nodeIndex].id
                matches[node.index].winnerDestinationSlot = edge.slot
            }
            if let edge = node.loserTo {
                matches[node.index].loserDestinationId = matches[edge.nodeIndex].id
                matches[node.index].loserDestinationSlot = edge.slot
            }
        }

        return matches
    }
}
