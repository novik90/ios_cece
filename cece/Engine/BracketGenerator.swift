import Foundation

/// A directed edge to a target node's slot within a generated bracket plan.
struct BracketEdge: Equatable {
    /// Index of the target node in `BracketPlan.nodes`.
    let nodeIndex: Int
    /// Which slot (1 or 2) of the target node this edge feeds.
    let slot: Int
}

/// A single node in a generated bracket plan.
///
/// Pure value type with no SwiftData dependency, so the generator stays unit
/// testable. `BracketPlan.makeMatches(players:)` materializes a plan into
/// persisted `TournamentMatch` nodes.
struct BracketNode: Equatable {
    /// Stable index of this node within `BracketPlan.nodes`.
    let index: Int
    let bracket: TournamentBracket
    let round: Int
    let position: Int

    /// Seeds (1...N) seated in the two slots. Set only for winners round 0.
    var seed1: Int?
    var seed2: Int?

    /// Where the winner of this node advances.
    var winnerTo: BracketEdge?
    /// Where the loser of this node drops. Nil when losing eliminates the
    /// player (losers-bracket and grand-final nodes).
    var loserTo: BracketEdge?
}

/// A fully wired double-elimination bracket for N ∈ {4, 8, 16}, as pure values.
struct BracketPlan: Equatable {
    let size: Int
    let nodes: [BracketNode]

    /// Nodes of a given bracket, ordered by round then position.
    func nodes(in bracket: TournamentBracket) -> [BracketNode] {
        nodes
            .filter { $0.bracket == bracket }
            .sorted { ($0.round, $0.position) < ($1.round, $1.position) }
    }

    /// Number of rounds in the winners bracket (log2 N).
    var winnersRoundCount: Int {
        (nodes(in: .winners).map(\.round).max() ?? -1) + 1
    }

    /// Number of rounds in the losers bracket (2·(log2 N − 1)).
    var losersRoundCount: Int {
        (nodes(in: .losers).map(\.round).max() ?? -1) + 1
    }
}

/// Generates double-elimination brackets.
///
/// Structure (W = log2 N winners rounds):
/// - Winners bracket: W rounds, N/2^(r+1) matches in round r.
/// - Losers bracket: 2·(W−1) rounds, alternating *minor* rounds (survivors play
///   each other) and *major* rounds (survivors meet a fresh batch of winners-
///   bracket losers). Round 0 is the special minor round seeded by the round-0
///   winners losers.
/// - Grand final: a single match (no bracket reset).
///
/// Inputs are powers of two, so there are never byes.
enum BracketGenerator {

    static func makePlan(size: TournamentSize) -> BracketPlan {
        let n = size.rawValue
        let w = n.trailingZeroBitCount  // winners rounds (n is a power of two)

        var nodes: [BracketNode] = []
        var indexByKey: [String: Int] = [:]

        func key(_ b: TournamentBracket, _ r: Int, _ p: Int) -> String {
            "\(b.rawValue)-\(r)-\(p)"
        }
        func add(_ b: TournamentBracket, _ r: Int, _ p: Int) {
            let i = nodes.count
            nodes.append(BracketNode(index: i, bracket: b, round: r, position: p))
            indexByKey[key(b, r, p)] = i
        }
        func idx(_ b: TournamentBracket, _ r: Int, _ p: Int) -> Int {
            indexByKey[key(b, r, p)]!
        }

        // Winners nodes.
        for r in 0..<w {
            let count = n / (1 << (r + 1))
            for p in 0..<count { add(.winners, r, p) }
        }
        // Losers nodes.
        let lbCounts = losersRoundCounts(n: n, w: w)
        for (r, count) in lbCounts.enumerated() {
            for p in 0..<count { add(.losers, r, p) }
        }
        // Grand final (single match).
        add(.grandFinal, 0, 0)

        // Seed winners round 0 with the standard 1...N seeding order.
        let order = seedingOrder(n)
        for p in 0..<(n / 2) {
            nodes[idx(.winners, 0, p)].seed1 = order[2 * p]
            nodes[idx(.winners, 0, p)].seed2 = order[2 * p + 1]
        }

        // Winners bracket edges.
        for r in 0..<w {
            let count = n / (1 << (r + 1))
            for p in 0..<count {
                let me = idx(.winners, r, p)
                // Winner advances within winners, or into the grand final.
                if r < w - 1 {
                    nodes[me].winnerTo = BracketEdge(
                        nodeIndex: idx(.winners, r + 1, p / 2),
                        slot: p % 2 == 0 ? 1 : 2
                    )
                } else {
                    nodes[me].winnerTo = BracketEdge(nodeIndex: idx(.grandFinal, 0, 0), slot: 1)
                }
                // Loser drops into the losers bracket.
                if r == 0 {
                    nodes[me].loserTo = BracketEdge(
                        nodeIndex: idx(.losers, 0, p / 2),
                        slot: p % 2 == 0 ? 1 : 2
                    )
                } else {
                    // Round r losers feed the major LB round 2r−1, in slot 2.
                    // Positions are reversed to push rematches as late as possible.
                    let lbRound = 2 * r - 1
                    let q = count - 1 - p
                    nodes[me].loserTo = BracketEdge(nodeIndex: idx(.losers, lbRound, q), slot: 2)
                }
            }
        }

        // Losers bracket winner edges (losers are eliminated, so no loserTo).
        let lbRounds = lbCounts.count
        for r in 0..<lbRounds {
            for p in 0..<lbCounts[r] {
                let me = idx(.losers, r, p)
                if r == lbRounds - 1 {
                    nodes[me].winnerTo = BracketEdge(nodeIndex: idx(.grandFinal, 0, 0), slot: 2)
                } else if (r + 1) % 2 == 1 {
                    // Next round is major (odd index): equal match count, survivor
                    // takes slot 1 (slot 2 receives a winners-bracket loser).
                    nodes[me].winnerTo = BracketEdge(nodeIndex: idx(.losers, r + 1, p), slot: 1)
                } else {
                    // Next round is minor (even index): survivors pair up.
                    nodes[me].winnerTo = BracketEdge(
                        nodeIndex: idx(.losers, r + 1, p / 2),
                        slot: p % 2 == 0 ? 1 : 2
                    )
                }
            }
        }

        return BracketPlan(size: n, nodes: nodes)
    }

    /// Standard single-elimination seeding order for N participants, e.g.
    /// `[1, 4, 2, 3]` for N = 4. Built so top seeds meet as late as possible.
    static func seedingOrder(_ n: Int) -> [Int] {
        var seeds = [1]
        while seeds.count < n {
            let size = seeds.count * 2
            var next: [Int] = []
            next.reserveCapacity(size)
            for s in seeds {
                next.append(s)
                next.append(size + 1 - s)
            }
            seeds = next
        }
        return seeds
    }

    /// Match counts per losers-bracket round.
    static func losersRoundCounts(n: Int, w: Int) -> [Int] {
        var counts: [Int] = []
        // Round 0: the N/2 round-0 winners losers pair into N/4 matches.
        var survivors = n / 2 / 2
        counts.append(survivors)
        for k in 1..<w {
            // Major round: survivors meet winners round-k losers (equal count).
            counts.append(survivors)
            // Minor round: survivors pair up (skip after the final major round).
            if k < w - 1 {
                survivors /= 2
                counts.append(survivors)
            }
        }
        return counts
    }
}
