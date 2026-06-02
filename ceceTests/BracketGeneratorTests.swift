import Testing
@testable import cece

/// Structure tests for the double-elimination generator across all sizes.
struct BracketGeneratorTests {

    private let sizes: [TournamentSize] = [.four, .eight, .sixteen]

    // MARK: Round counts

    @Test(arguments: [
        (TournamentSize.four, 2, 2),
        (TournamentSize.eight, 3, 4),
        (TournamentSize.sixteen, 4, 6),
    ])
    func roundCounts(size: TournamentSize, winners: Int, losers: Int) {
        let plan = BracketGenerator.makePlan(size: size)
        #expect(plan.winnersRoundCount == winners)
        #expect(plan.losersRoundCount == losers)
        // Exactly one grand-final match.
        #expect(plan.nodes(in: .grandFinal).count == 1)
    }

    // MARK: Match counts per round

    @Test func winnersMatchCountsHalveEachRound() {
        for size in sizes {
            let plan = BracketGenerator.makePlan(size: size)
            let n = size.rawValue
            for r in 0..<plan.winnersRoundCount {
                let count = plan.nodes(in: .winners).filter { $0.round == r }.count
                #expect(count == n / (1 << (r + 1)))
            }
        }
    }

    @Test func losersBracketEndsInSingleMatch() {
        for size in sizes {
            let plan = BracketGenerator.makePlan(size: size)
            let lastRound = plan.losersRoundCount - 1
            let finalMatches = plan.nodes(in: .losers).filter { $0.round == lastRound }
            #expect(finalMatches.count == 1)
        }
    }

    // MARK: No byes — every winners round-0 slot is seeded exactly once

    @Test func seedingHasNoByesAndCoversAllSeeds() {
        for size in sizes {
            let plan = BracketGenerator.makePlan(size: size)
            let n = size.rawValue
            let round0 = plan.nodes(in: .winners).filter { $0.round == 0 }

            #expect(round0.count == n / 2)
            for node in round0 {
                #expect(node.seed1 != nil)
                #expect(node.seed2 != nil)
            }

            let seeds = round0.flatMap { [$0.seed1, $0.seed2].compactMap { $0 } }.sorted()
            #expect(seeds == Array(1...n))
        }
    }

    @Test func topSeedsAreSeparatedInRoundZero() {
        // Standard seeding: seed 1 and seed 2 must not share a round-0 match.
        for size in sizes {
            let plan = BracketGenerator.makePlan(size: size)
            let round0 = plan.nodes(in: .winners).filter { $0.round == 0 }
            let topMatch = round0.first { $0.seed1 == 1 || $0.seed2 == 1 }
            #expect(topMatch != nil)
            #expect(topMatch?.seed1 != 2 && topMatch?.seed2 != 2)
        }
    }

    // MARK: Link correctness — every produced edge targets a valid node/slot

    @Test func everyEdgeTargetsAValidNodeAndSlot() {
        for size in sizes {
            let plan = BracketGenerator.makePlan(size: size)
            for node in plan.nodes {
                for edge in [node.winnerTo, node.loserTo].compactMap({ $0 }) {
                    #expect(plan.nodes.indices.contains(edge.nodeIndex))
                    #expect(edge.slot == 1 || edge.slot == 2)
                }
            }
        }
    }

    /// Winners nodes always route both winner and loser; losers/grand-final
    /// nodes never route a loser (losing eliminates).
    @Test func advancementWiringMatchesBracketRules() {
        for size in sizes {
            let plan = BracketGenerator.makePlan(size: size)
            for node in plan.nodes(in: .winners) {
                #expect(node.winnerTo != nil)
                #expect(node.loserTo != nil)
            }
            for node in plan.nodes(in: .losers) {
                #expect(node.loserTo == nil)
            }
            for node in plan.nodes(in: .grandFinal) {
                #expect(node.winnerTo == nil)
                #expect(node.loserTo == nil)
            }
        }
    }

    /// Every slot that is not a seeded winners round-0 slot must be filled by
    /// exactly one incoming edge — no collisions, no gaps.
    @Test func everyNonSeededSlotHasExactlyOneFeeder() {
        for size in sizes {
            let plan = BracketGenerator.makePlan(size: size)

            // Collect all target (node, slot) pairs from edges.
            var feeders: [String: Int] = [:]
            for node in plan.nodes {
                for edge in [node.winnerTo, node.loserTo].compactMap({ $0 }) {
                    feeders["\(edge.nodeIndex)-\(edge.slot)", default: 0] += 1
                }
            }

            for node in plan.nodes {
                for slot in 1...2 {
                    let isSeeded = node.bracket == .winners && node.round == 0
                    let key = "\(node.index)-\(slot)"
                    if isSeeded {
                        #expect(feeders[key] == nil)  // seeded, not fed by an edge
                    } else {
                        #expect(feeders[key] == 1)    // exactly one feeder
                    }
                }
            }
        }
    }
}
