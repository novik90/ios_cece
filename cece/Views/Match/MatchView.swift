import SwiftUI
import SwiftData

/// Match tab entry point. Lists in-progress matches so the user can choose which
/// to play. Completed matches live in the stats tab.
struct MatchView: View {
    @EnvironmentObject private var dependencies: Dependencies
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Match> { $0.completedAt == nil },
        sort: \Match.createdAt,
        order: .reverse
    )
    private var activeMatches: [Match]
    @State private var pendingDelete: Match?

    private var playableMatches: [Match] {
        activeMatches.filter { $0.player1 != nil && $0.player2 != nil }
    }

    var body: some View {
        NavigationStack {
            Group {
                if playableMatches.isEmpty {
                    ContentUnavailableView(
                        "No active match",
                        systemImage: "target",
                        description: Text("Create a match from the home screen to start scoring.")
                    )
                } else {
                    List {
                        Section("In progress") {
                            ForEach(playableMatches) { match in
                                NavigationLink(value: match) {
                                    ActiveMatchRow(match: match)
                                }
                                .deleteSwipeAction { pendingDelete = match }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Matches")
            .navigationDestination(for: Match.self) { match in
                MatchPlayView(viewModel: dependencies.liveMatchViewModel(for: match))
            }
            .deleteConfirmation(
                "Delete match?",
                item: $pendingDelete,
                message: "This permanently deletes the match in progress and all its frames.",
                confirmLabel: "Delete match"
            ) { delete($0) }
        }
    }

    private func delete(_ match: Match) {
        dependencies.releaseMatchViewModel(for: match.id)
        modelContext.delete(match)
        try? modelContext.save()
    }
}

private struct ActiveMatchRow: View {
    let match: Match

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(match.player1?.name ?? "—") vs \(match.player2?.name ?? "—")")
                    .font(.body)
                Text("Best of \(match.totalFrames) · \(match.frames.count) frame\(match.frames.count == 1 ? "" : "s") played")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(match.framesWon(by: match.player1)) – \(match.framesWon(by: match.player2))")
                .font(.headline.monospacedDigit())
        }
    }
}

// MARK: - Live scoring screen

struct MatchPlayView: View {
    @State private var viewModel: MatchViewModel

    init(viewModel: MatchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Text(viewModel.frameNumberText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ScoreboardView(viewModel: viewModel)

                    if viewModel.respottedBlack {
                        RespottedBlackBanner()
                    }

                    BreakSummaryView(viewModel: viewModel)

                    Divider()

                    ActionsRow(viewModel: viewModel)

                    BallGridView(viewModel: viewModel)

                    if viewModel.freeBallAvailable && !viewModel.matchCompleted {
                        FreeBallBanner(viewModel: viewModel)
                    }

                    endButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            if viewModel.matchCompleted {
                CompletionOverlay(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.showFoulSheet) {
            FoulPenaltySheet(viewModel: viewModel)
                .presentationDetents([.height(220)])
        }
        .sheet(isPresented: $viewModel.showFoulTurnChoice) {
            FoulTurnSheet(viewModel: viewModel)
                .presentationDetents([.height(240)])
        }
        .sheet(isPresented: $viewModel.showEditSheet) {
            FrameEditSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $viewModel.showRespottedBlackChoice) {
            RespottedBlackSheet(viewModel: viewModel)
                .presentationDetents([.height(280)])
                .interactiveDismissDisabled()
        }
    }

    private var endButtonTitle: String {
        if viewModel.isEndFrame { return "End frame" }
        return viewModel.currentBreakBalls.isEmpty ? "Miss / safety" : "End break"
    }

    private var endButton: some View {
        Button {
            if viewModel.isEndFrame { viewModel.endFrame() } else { viewModel.endBreak() }
        } label: {
            Label(endButtonTitle, systemImage: "circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .foregroundStyle(.white)
        .background(Theme.Palette.teal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .disabled(viewModel.matchCompleted)
        .opacity(viewModel.matchCompleted ? 0.4 : 1)
    }
}

// MARK: - Scoreboard

private struct ScoreboardView: View {
    let viewModel: MatchViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            column(for: viewModel.player1Id)
            frameScore
            column(for: viewModel.player2Id)
        }
    }

    /// Frames won: "1 (5) 0" — left wins, best-of total, right wins.
    private var frameScore: some View {
        Text("\(viewModel.framesWon(by: viewModel.player1Id)) (\(viewModel.match.totalFrames)) \(viewModel.framesWon(by: viewModel.player2Id))")
            .font(.title3.weight(.bold).monospacedDigit())
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    private func column(for playerId: UUID) -> some View {
        let isActive = viewModel.activePlayerId == playerId
        let myScore = viewModel.score(for: playerId)
        let diff = myScore - viewModel.score(for: viewModel.opponent(of: playerId))

        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(viewModel.name(for: playerId))
                    .font(.headline)
                    .foregroundStyle(isActive ? Theme.Palette.teal : Theme.Palette.textPrimary)
                    .lineLimit(1)
                if isActive {
                    Circle().fill(Theme.Palette.teal).frame(width: 8, height: 8)
                }
            }

            Text("\(myScore)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)

            differenceLabel(diff)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func differenceLabel(_ diff: Int) -> some View {
        if diff > 0 {
            Text("Ahead: \(diff)").font(.caption).foregroundStyle(Theme.Palette.teal)
        } else if diff < 0 {
            Text("Behind: \(-diff)").font(.caption).foregroundStyle(Theme.Palette.destructive)
        } else {
            // Level: keep the row height, show nothing.
            Text("Ahead: 0").font(.caption).hidden()
        }
    }
}

// MARK: - Break summary

private struct BreakSummaryView: View {
    let viewModel: MatchViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Break").font(.subheadline).foregroundStyle(.secondary)
                Text("\(viewModel.currentBreakPoints) pts").font(.subheadline.weight(.semibold))
                Spacer()
                Text("On table: \(viewModel.pointsOnTable)").font(.subheadline).foregroundStyle(.secondary)
            }

            if viewModel.breakSummary.isEmpty {
                HStack {
                    Circle()
                        .strokeBorder(Theme.Palette.textSecondary.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    Spacer()
                }
                .frame(height: 18)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.breakSummary, id: \.ball) { entry in
                            HStack(spacing: 4) {
                                Circle().fill(entry.ball.color).frame(width: 16, height: 16)
                                Text("×\(entry.count)").font(.subheadline.weight(.medium))
                            }
                        }
                    }
                }
                .frame(height: 18)
            }
        }
        .padding(14)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Actions row

private struct ActionsRow: View {
    let viewModel: MatchViewModel

    var body: some View {
        HStack(spacing: 12) {
            actionButton(system: "arrow.uturn.backward", label: "Undo") {
                viewModel.undoLastAction()
            }
            .disabled(!viewModel.canUndo)

            actionButton(system: "pencil", label: "Edit") {
                viewModel.showEditSheet = true
            }
            .disabled(viewModel.matchCompleted)

            actionButton(system: "flag.fill", label: "Foul", foreground: .white, background: Theme.Palette.destructive) {
                viewModel.beginFoul()
            }
            .disabled(viewModel.matchCompleted)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func actionButton(
        system: String,
        label: String,
        foreground: Color = Theme.Palette.textPrimary,
        background: Color = Theme.Palette.surface,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: system).font(.system(size: 18, weight: .semibold))
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .foregroundStyle(foreground)
        .background(background, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Free ball

private struct FreeBallBanner: View {
    @Bindable var viewModel: MatchViewModel

    var body: some View {
        Button {
            viewModel.freeBallArmed.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: viewModel.freeBallArmed ? "a.circle.fill" : "a.circle")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Free ball").font(.subheadline.weight(.semibold))
                    Text(viewModel.freeBallArmed
                         ? "Tap the ball you played — scores \(viewModel.freeBallValue)"
                         : "Snookered after a foul? Tap to nominate a free ball.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text(viewModel.freeBallArmed ? "Cancel" : "+\(viewModel.freeBallValue)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(viewModel.freeBallArmed ? Theme.Palette.destructive : Theme.Palette.teal)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(viewModel.freeBallArmed ? Theme.Palette.teal.opacity(0.10) : Color.clear)
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.Palette.teal, lineWidth: 1.5)
            )
        }
        .foregroundStyle(Theme.Palette.textPrimary)
    }
}

// MARK: - Respotted black

private struct RespottedBlackBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.Ball.black).frame(width: 14, height: 14)
            Text("Respotted black — sudden death").font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.Ball.black.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.Ball.black.opacity(0.5), lineWidth: 1))
    }
}

private struct RespottedBlackSheet: View {
    let viewModel: MatchViewModel

    var body: some View {
        VStack(spacing: 16) {
            Circle().fill(Theme.Ball.black).frame(width: 40, height: 40)
            Text("Scores level!").font(.title2.weight(.bold))
            Text("The black is respotted. Toss to decide who plays first — first to pot the black wins; a foul loses the frame.")
                .font(.footnote).multilineTextAlignment(.center).foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach([viewModel.player1Id, viewModel.player2Id], id: \.self) { id in
                    Button {
                        viewModel.chooseRespottedBlackFirstPlayer(id)
                    } label: {
                        Text("\(viewModel.name(for: id)) plays first")
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .foregroundStyle(.white)
                    .background(Theme.Palette.teal, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(24)
    }
}

// MARK: - Ball grid

private struct BallGridView: View {
    let viewModel: MatchViewModel

    private let colours: [SnookerBall] = [.yellow, .green, .brown, .blue, .pink, .black]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(colours, id: \.self) { ball in
                    BallButton(ball: ball, viewModel: viewModel)
                }
            }
            BallButton(ball: .red, viewModel: viewModel, wide: true)
        }
    }
}

private struct BallButton: View {
    let ball: SnookerBall
    let viewModel: MatchViewModel
    var wide: Bool = false

    private var nominating: Bool { viewModel.freeBallArmed }

    private var available: Bool {
        if nominating { return viewModel.isFreeBallNominatable(ball) }
        return viewModel.isBallAvailable(ball) && !viewModel.matchCompleted
    }

    private var scoresAsColor: Color? {
        guard nominating, available, let onBall = viewModel.onBall else { return nil }
        return onBall.color
    }

    var body: some View {
        Button {
            if nominating { viewModel.potFreeBall() } else { viewModel.potBall(ball) }
        } label: {
            Text("\(ball.rawValue)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(ball.textColor)
                .frame(maxWidth: .infinity)
                .frame(height: wide ? 56 : 64)
                .background(ball.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if let badge = scoresAsColor {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(badge)
                            .frame(width: 18, height: 18)
                            .overlay {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(.white.opacity(0.85), lineWidth: 1.5)
                            }
                            .padding(6)
                    }
                }
        }
        .opacity(available ? 1 : 0.3)
        .disabled(!available)
    }
}

// MARK: - Foul sheets

private struct FoulPenaltySheet: View {
    let viewModel: MatchViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Foul — choose penalty").font(.headline)
            HStack(spacing: 12) {
                ForEach([4, 5, 6, 7], id: \.self) { points in
                    Button {
                        viewModel.selectFoulPoints(points)
                    } label: {
                        Text("\(points)")
                            .font(.title2.weight(.bold))
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                    .foregroundStyle(.white)
                    .background(Theme.Palette.destructive, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            Text("Awarded to the opponent.").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

private struct FoulTurnSheet: View {
    let viewModel: MatchViewModel

    var body: some View {
        let offender = viewModel.activePlayerId
        let opponent = viewModel.opponentId

        return VStack(spacing: 16) {
            Text("Who plays next?").font(.headline)
            Text("+\(viewModel.pendingFoulPoints) to \(viewModel.name(for: opponent))")
                .font(.subheadline).foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Button {
                    viewModel.applyFoul(nextPlayerId: opponent)
                } label: {
                    Text("\(viewModel.name(for: opponent)) plays")
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .foregroundStyle(.white)
                .background(Theme.Palette.teal, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    viewModel.applyFoul(nextPlayerId: offender)
                } label: {
                    Text("\(viewModel.name(for: offender)) plays again")
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .foregroundStyle(Theme.Palette.textPrimary)
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
    }
}

// MARK: - Edit sheet

private struct FrameEditSheet: View {
    let viewModel: MatchViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmEndMatch = false

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.gamePhase == .reds {
                    Section("Reds on table") {
                        Stepper(
                            "Reds remaining: \(viewModel.redsRemaining)",
                            onIncrement: { viewModel.restoreRed() },
                            onDecrement: { viewModel.removeRed() }
                        )
                        Text("Use if a red left the table without being potted. Points on table recalculate automatically.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Concede frame") {
                    Text("Award the current frame and move on.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("\(viewModel.name(for: viewModel.player1Id)) wins frame") {
                        viewModel.endFrame(forcedWinner: viewModel.player1Id); dismiss()
                    }
                    Button("\(viewModel.name(for: viewModel.player2Id)) wins frame") {
                        viewModel.endFrame(forcedWinner: viewModel.player2Id); dismiss()
                    }
                }

                Section("End match early") {
                    Text("Use when a player cannot finish the match.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button(role: .destructive) {
                        confirmEndMatch = true
                    } label: {
                        Label("End match…", systemImage: "flag.checkered")
                    }
                }
            }
            .navigationTitle("Edit frame")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Award match to:", isPresented: $confirmEndMatch, titleVisibility: .visible) {
                Button(viewModel.name(for: viewModel.player1Id)) {
                    viewModel.concedeMatch(winnerId: viewModel.player1Id); dismiss()
                }
                Button(viewModel.name(for: viewModel.player2Id)) {
                    viewModel.concedeMatch(winnerId: viewModel.player2Id); dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

// MARK: - Completion overlay

private struct CompletionOverlay: View {
    let viewModel: MatchViewModel
    @Environment(\.dismiss) private var dismiss

    private var winnerId: UUID {
        if let explicit = viewModel.match.winnerId { return explicit }
        return viewModel.framesWon(by: viewModel.player1Id) >= viewModel.framesWon(by: viewModel.player2Id)
            ? viewModel.player1Id : viewModel.player2Id
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.Palette.teal)
                Text("Match complete").font(.title2.weight(.bold))
                Text("Winner: \(viewModel.name(for: winnerId))").font(.headline)
                Text("\(viewModel.framesWon(by: viewModel.player1Id)) – \(viewModel.framesWon(by: viewModel.player2Id)) frames")
                    .font(.subheadline).foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Back to matches").frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .foregroundStyle(.white)
                    .background(Theme.Palette.teal, in: RoundedRectangle(cornerRadius: 12))

                    Button {
                        viewModel.undoLastAction()
                    } label: {
                        Text("Undo last frame").frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(28)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
            .padding(40)
        }
    }
}

// MARK: - Preview

#Preview {
    let vm = MatchViewModel(
        match: PreviewData.previewMatch,
        context: PreviewData.container.mainContext
    )
    vm.currentFrameIndex = 2
    vm.scores[vm.player1Id] = 75
    vm.scores[vm.player2Id] = 62
    vm.redsRemaining = 11
    vm.currentBreakBalls = [.red, .black, .red, .black, .red, .black, .red, .green]
    return MatchPlayView(viewModel: vm)
}
