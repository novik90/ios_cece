import Foundation
import SwiftData
import Observation

/// The snooker scoring engine. The whole game runs in memory; a `Frame` (with
/// its `Break`s) is only written to SwiftData when the frame is completed.
@MainActor
@Observable
final class MatchViewModel {
    // MARK: Stored game state

    let match: Match
    let player1Id: UUID
    let player2Id: UUID

    var currentFrameIndex: Int
    var activePlayerId: UUID

    /// Current-frame points per player (kept in memory until the frame ends).
    var scores: [UUID: Int]

    var currentBreakBalls: [SnookerBall] = []
    var redsRemaining: Int = 15
    var gamePhase: GamePhase = .reds
    /// How many colours have been potted during the colours phase (0...6).
    var colorsPottedInOrder: Int = 0

    var matchCompleted: Bool = false

    // Foul UI flow
    var showFoulSheet: Bool = false
    var showFoulTurnChoice: Bool = false
    var pendingFoulPoints: Int = 0

    // Edit menu
    var showEditSheet: Bool = false

    // Free ball
    var freeBallAvailable: Bool = false
    var freeBallArmed: Bool = false
    /// After a free ball in the reds phase a colour is strictly required.
    var colorDueAfterFreeBall: Bool = false

    // Respotted black (level scores sudden death)
    var respottedBlack: Bool = false
    var showRespottedBlackChoice: Bool = false

    // MARK: Persistence / history (not observed for UI)

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private var actionHistory: [MatchAction] = []
    /// State snapshots powering a robust single-step undo. NOT ignored: `canUndo`
    /// is read by the UI.
    private var snapshots: [Snapshot] = []
    @ObservationIgnored private var completedBreaks: [(playerId: UUID, balls: [SnookerBall])] = []

    // MARK: Init

    init(match: Match, context: ModelContext) {
        self.match = match
        self.context = context
        let p1 = match.player1?.id ?? UUID()
        let p2 = match.player2?.id ?? UUID()
        self.player1Id = p1
        self.player2Id = p2
        self.activePlayerId = p1
        self.scores = [p1: 0, p2: 0]
        self.currentFrameIndex = match.frames.count
    }

    // MARK: - Derived state

    var currentBreakPoints: Int { currentBreakBalls.reduce(0) { $0 + $1.rawValue } }

    func score(for playerId: UUID) -> Int { scores[playerId, default: 0] }

    var opponentId: UUID { opponent(of: activePlayerId) }
    func opponent(of id: UUID) -> UUID { id == player1Id ? player2Id : player1Id }

    func name(for id: UUID) -> String {
        if id == player1Id { return match.player1?.name ?? "Player 1" }
        return match.player2?.name ?? "Player 2"
    }

    func framesWon(by playerId: UUID) -> Int {
        match.frames.filter { $0.winnerId == playerId }.count
    }

    private var lastBallWasColored: Bool {
        guard let last = currentBreakBalls.last else { return false }
        return last != .red
    }

    /// Whether a red is currently the ball "on".
    var isRedOn: Bool {
        gamePhase == .reds && redsRemaining > 0 && (currentBreakBalls.isEmpty || lastBallWasColored)
    }

    /// The ball currently "on" — the minimum-value ball on the table.
    var onBall: SnookerBall? {
        gamePhase == .reds ? .red : nextColorBall
    }

    var freeBallValue: Int { onBall?.rawValue ?? 0 }

    var nextColorBall: SnookerBall? {
        guard gamePhase == .colors, colorsPottedInOrder < SnookerBall.colourSequence.count else { return nil }
        return SnookerBall.colourSequence[colorsPottedInOrder]
    }

    var colorsRemaining: [SnookerBall] {
        guard gamePhase == .colors else { return SnookerBall.colourSequence }
        return Array(SnookerBall.colourSequence[colorsPottedInOrder...])
    }

    /// Colours physically still on the table.
    var ballsOnTable: [SnookerBall] {
        gamePhase == .reds ? SnookerBall.colourSequence : colorsRemaining
    }

    var pointsOnTable: Int {
        if gamePhase == .reds {
            return redsRemaining * 8 + 27
        } else {
            return colorsRemaining.reduce(0) { $0 + $1.rawValue }
        }
    }

    func isBallAvailable(_ ball: SnookerBall) -> Bool {
        switch gamePhase {
        case .reds:
            if colorDueAfterFreeBall { return ball != .red }
            if redsRemaining == 0 { return ball != .red }
            if currentBreakBalls.isEmpty || lastBallWasColored { return ball == .red }
            return true
        case .colors:
            return ball == nextColorBall
        }
    }

    /// Whether a ball may be nominated as the free ball: on the table and not the
    /// ball on.
    func isFreeBallNominatable(_ ball: SnookerBall) -> Bool {
        guard freeBallArmed, freeBallAvailable, !matchCompleted else { return false }
        guard ball != .red, ball != onBall else { return false }
        return ballsOnTable.contains(ball)
    }

    var breakSummary: [(ball: SnookerBall, count: Int)] {
        var order: [SnookerBall] = []
        var counts: [SnookerBall: Int] = [:]
        for ball in currentBreakBalls {
            if counts[ball] == nil { order.append(ball) }
            counts[ball, default: 0] += 1
        }
        return order.map { ($0, counts[$0] ?? 0) }
    }

    /// End frame is offered when the black is potted, or only the black remains
    /// and the lead is more than 7 (so foul points can no longer decide it).
    var isEndFrame: Bool {
        guard gamePhase == .colors else { return false }
        if colorsPottedInOrder >= SnookerBall.colourSequence.count { return true }
        if colorsRemaining == [.black] {
            return abs(score(for: player1Id) - score(for: player2Id)) > 7
        }
        return false
    }

    var frameNumberText: String { "Frame \(currentFrameIndex + 1) of \(match.totalFrames)" }

    // MARK: - Actions

    func potBall(_ ball: SnookerBall) {
        guard isBallAvailable(ball), !matchCompleted else { return }
        pushHistory()

        freeBallAvailable = false
        freeBallArmed = false
        colorDueAfterFreeBall = false
        currentBreakBalls.append(ball)
        scores[activePlayerId, default: 0] += ball.rawValue
        if ball == .red { redsRemaining -= 1 }
        if gamePhase == .colors { colorsPottedInOrder += 1 }

        actionHistory.append(.ballPotted(playerId: activePlayerId, ball: ball))
        updateGamePhase()

        // Potting the final black to leave the scores level -> respotted black.
        if gamePhase == .colors,
           colorsPottedInOrder >= SnookerBall.colourSequence.count,
           score(for: player1Id) == score(for: player2Id) {
            setupRespottedBlack()
        }
    }

    /// Play a free ball: scores the value of the ball on (the minimum). The
    /// nominated ball is re-spotted, the ball on stays; in the reds phase it
    /// counts as a red (a colour is then due) without removing a real red.
    func potFreeBall() {
        guard freeBallAvailable, !matchCompleted, freeBallValue > 0 else { return }
        pushHistory()

        freeBallAvailable = false
        freeBallArmed = false

        let value = freeBallValue
        scores[activePlayerId, default: 0] += value
        let scoredBall = SnookerBall(rawValue: value) ?? .red
        currentBreakBalls.append(scoredBall)
        actionHistory.append(.ballPotted(playerId: activePlayerId, ball: scoredBall))
        if gamePhase == .reds { colorDueAfterFreeBall = true }
    }

    private func updateGamePhase() {
        if gamePhase == .reds, redsRemaining == 0, lastBallWasColored {
            gamePhase = .colors
            colorsPottedInOrder = 0
        }
    }

    func endBreak() {
        guard !matchCompleted else { return }
        pushHistory()
        freeBallAvailable = false
        freeBallArmed = false
        colorDueAfterFreeBall = false
        let from = activePlayerId
        let to = opponentId
        flushCurrentBreak()
        actionHistory.append(.endBreak(fromPlayerId: from, toPlayerId: to))
        activePlayerId = to
    }

    // MARK: Foul flow

    func beginFoul() {
        guard !matchCompleted else { return }
        showFoulSheet = true
    }

    func selectFoulPoints(_ points: Int) {
        pendingFoulPoints = points
        showFoulSheet = false
        showFoulTurnChoice = true
    }

    func applyFoul(nextPlayerId: UUID) {
        pushHistory()
        let offender = activePlayerId
        let receiver = opponent(of: offender)
        flushCurrentBreak()
        scores[receiver, default: 0] += pendingFoulPoints

        // A foul on the respotted black loses the frame for the offender.
        if respottedBlack {
            showFoulTurnChoice = false
            pendingFoulPoints = 0
            finalizeFrame(winnerId: receiver)
            return
        }

        actionHistory.append(.foul(
            penaltyPoints: pendingFoulPoints,
            receivingPlayerId: receiver,
            nextPlayerId: nextPlayerId
        ))
        activePlayerId = nextPlayerId
        freeBallAvailable = (nextPlayerId != offender)
        freeBallArmed = false
        colorDueAfterFreeBall = false
        showFoulTurnChoice = false
        pendingFoulPoints = 0

        if gamePhase == .colors,
           colorsRemaining == [.black],
           score(for: player1Id) == score(for: player2Id) {
            setupRespottedBlack()
        }
    }

    // MARK: Edit / corrections

    func removeRed() {
        guard gamePhase == .reds, redsRemaining > 0, !matchCompleted else { return }
        pushHistory()
        redsRemaining -= 1
        actionHistory.append(.edit)
    }

    func restoreRed() {
        guard gamePhase == .reds, redsRemaining < 15, !matchCompleted else { return }
        pushHistory()
        redsRemaining += 1
        actionHistory.append(.edit)
    }

    func concedeMatch(winnerId: UUID) {
        guard !matchCompleted else { return }
        pushHistory()
        flushCurrentBreak()
        match.winnerId = winnerId
        match.completedAt = .now
        matchCompleted = true
        actionHistory.append(.edit)
        try? context.save()
    }

    // MARK: Respotted black

    private func setupRespottedBlack() {
        flushCurrentBreak()
        colorsPottedInOrder = SnookerBall.colourSequence.count - 1 // only the black remains
        respottedBlack = true
        showRespottedBlackChoice = true
    }

    func chooseRespottedBlackFirstPlayer(_ id: UUID) {
        activePlayerId = id
        showRespottedBlackChoice = false
    }

    // MARK: End frame

    func endFrame(forcedWinner: UUID? = nil) {
        guard !matchCompleted else { return }
        pushHistory()
        flushCurrentBreak()

        let s1 = score(for: player1Id), s2 = score(for: player2Id)
        let winnerId: UUID = forcedWinner ?? (s1 >= s2 ? player1Id : player2Id)
        finalizeFrame(winnerId: winnerId)
    }

    /// Records the current frame's result and ends the match or starts the next
    /// frame. Caller has already pushed history and flushed the break.
    private func finalizeFrame(winnerId: UUID) {
        respottedBlack = false
        showRespottedBlackChoice = false

        let s1 = score(for: player1Id), s2 = score(for: player2Id)
        let frame = Frame(
            frameNumber: currentFrameIndex + 1,
            player1Score: s1,
            player2Score: s2,
            winnerId: winnerId
        )
        for rec in completedBreaks {
            let brk = Break(
                playerId: rec.playerId,
                balls: rec.balls.map(\.rawValue),
                points: rec.balls.reduce(0) { $0 + $1.rawValue }
            )
            frame.breaks.append(brk)
        }
        frame.match = match
        match.frames.append(frame)
        context.insert(frame)

        actionHistory.append(.endFrame(winnerId: winnerId))

        let decided = framesWon(by: winnerId) >= match.framesToWin
        let framesExhausted = match.frames.count >= match.totalFrames
        if decided || framesExhausted {
            match.winnerId = winnerId
            match.completedAt = .now
            matchCompleted = true
        } else {
            startNextFrame(previousWinner: winnerId)
        }
        try? context.save()
    }

    private func startNextFrame(previousWinner: UUID) {
        currentFrameIndex += 1
        scores = [player1Id: 0, player2Id: 0]
        currentBreakBalls = []
        completedBreaks = []
        redsRemaining = 15
        gamePhase = .reds
        colorsPottedInOrder = 0
        freeBallAvailable = false
        freeBallArmed = false
        colorDueAfterFreeBall = false
        respottedBlack = false
        showRespottedBlackChoice = false
        activePlayerId = opponent(of: previousWinner)
    }

    private func flushCurrentBreak() {
        if !currentBreakBalls.isEmpty {
            completedBreaks.append((playerId: activePlayerId, balls: currentBreakBalls))
        }
        currentBreakBalls = []
    }

    // MARK: - Undo

    var canUndo: Bool { !snapshots.isEmpty }

    func undoLastAction() {
        guard let snap = snapshots.popLast() else { return }
        let action = actionHistory.popLast()

        if case .endFrame = action {
            let frameNo = snap.currentFrameIndex + 1
            if let saved = match.frames.first(where: { $0.frameNumber == frameNo }) {
                match.frames.removeAll { $0.id == saved.id }
                context.delete(saved)
            }
        }

        restore(snap)
        freeBallArmed = false
        showRespottedBlackChoice = false

        if !matchCompleted {
            match.completedAt = nil
            match.winnerId = nil
        }
        try? context.save()
    }

    // MARK: - Snapshots

    private struct Snapshot {
        var currentFrameIndex: Int
        var activePlayerId: UUID
        var scores: [UUID: Int]
        var currentBreakBalls: [SnookerBall]
        var redsRemaining: Int
        var gamePhase: GamePhase
        var colorsPottedInOrder: Int
        var completedBreaks: [(playerId: UUID, balls: [SnookerBall])]
        var matchCompleted: Bool
        var freeBallAvailable: Bool
        var colorDueAfterFreeBall: Bool
        var respottedBlack: Bool
    }

    private func pushHistory() {
        snapshots.append(Snapshot(
            currentFrameIndex: currentFrameIndex,
            activePlayerId: activePlayerId,
            scores: scores,
            currentBreakBalls: currentBreakBalls,
            redsRemaining: redsRemaining,
            gamePhase: gamePhase,
            colorsPottedInOrder: colorsPottedInOrder,
            completedBreaks: completedBreaks,
            matchCompleted: matchCompleted,
            freeBallAvailable: freeBallAvailable,
            colorDueAfterFreeBall: colorDueAfterFreeBall,
            respottedBlack: respottedBlack
        ))
    }

    private func restore(_ snap: Snapshot) {
        currentFrameIndex = snap.currentFrameIndex
        activePlayerId = snap.activePlayerId
        scores = snap.scores
        currentBreakBalls = snap.currentBreakBalls
        redsRemaining = snap.redsRemaining
        gamePhase = snap.gamePhase
        colorsPottedInOrder = snap.colorsPottedInOrder
        completedBreaks = snap.completedBreaks
        matchCompleted = snap.matchCompleted
        freeBallAvailable = snap.freeBallAvailable
        colorDueAfterFreeBall = snap.colorDueAfterFreeBall
        respottedBlack = snap.respottedBlack
    }
}
