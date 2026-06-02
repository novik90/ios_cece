import Foundation

/// Propagates match results through a tournament bracket.
///
/// When a node's match is decided, the winner is seated into its winner
/// destination slot and the loser into its loser destination slot (the wiring
/// produced by `BracketGenerator`/`BracketPlan.makeMatches`). Deciding the grand
/// final crowns the champion — there is no bracket reset, so a single grand
/// final match ends the tournament.
@MainActor
enum TournamentAdvancer {

    /// Propagates the result of `node`, reading the winner from its linked match.
    /// No-op if the match has no recorded winner yet.
    static func recordResult(for node: TournamentMatch, in tournament: Tournament) {
        guard let winnerId = node.match?.winnerId else { return }
        recordWinner(winnerId, of: node, in: tournament)
    }

    /// Propagates an explicit `winnerId` for `node` through the bracket.
    static func recordWinner(_ winnerId: UUID, of node: TournamentMatch, in tournament: Tournament) {
        let loserId = node.slot1PlayerId == winnerId ? node.slot2PlayerId : node.slot1PlayerId

        // Grand final decides the tournament; no further routing.
        if node.bracket == .grandFinal {
            tournament.championId = winnerId
            if tournament.completedAt == nil { tournament.completedAt = .now }
            return
        }

        let byId = Dictionary(uniqueKeysWithValues: tournament.matches.map { ($0.id, $0) })

        if let destId = node.winnerDestinationId,
           let slot = node.winnerDestinationSlot,
           let dest = byId[destId] {
            place(winnerId, into: dest, slot: slot)
        }

        if let loserId,
           let destId = node.loserDestinationId,
           let slot = node.loserDestinationSlot,
           let dest = byId[destId] {
            place(loserId, into: dest, slot: slot)
        }
    }

    private static func place(_ playerId: UUID, into node: TournamentMatch, slot: Int) {
        if slot == 1 {
            node.slot1PlayerId = playerId
        } else {
            node.slot2PlayerId = playerId
        }
    }
}
