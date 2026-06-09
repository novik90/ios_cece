import SwiftUI

/// Live scoring screen, driven entirely by server-pushed `MatchLiveState`.
/// Block F1: renders state and dispatches actions through a `MatchChannel`.
struct OnlineMatchPlayView: View {
    @StateObject private var viewModel: MatchScoringViewModel
    @State private var showFoul = false
    @State private var showConcede = false

    init(channel: MatchChannel, myUserId: String?) {
        _viewModel = StateObject(wrappedValue: MatchScoringViewModel(channel: channel, myUserId: myUserId))
    }

    var body: some View {
        Group {
            if let state = viewModel.state {
                content(state)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(connectionLabel).foregroundStyle(.secondary).font(.footnote)
                }
            }
        }
        .navigationTitle("Match")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.mySlot != nil && !viewModel.isCompleted {
                ToolbarItem(placement: .primaryAction) {
                    Button("Concede", role: .destructive) { showConcede = true }
                }
            }
        }
        .confirmationDialog("Concede", isPresented: $showConcede, titleVisibility: .visible) {
            Button("Concede frame", role: .destructive) { viewModel.concedeFrame() }
            Button("Concede match", role: .destructive) { viewModel.concedeMatch() }
            Button("Cancel", role: .cancel) {}
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var connectionLabel: String {
        switch viewModel.connection {
        case .connecting: return "Connecting…"
        case .connected: return "Waiting for the match to start…"
        case .disconnected: return "Disconnected"
        }
    }

    @ViewBuilder
    private func content(_ state: API.MatchLiveState) -> some View {
        VStack(spacing: 16) {
            if viewModel.connection != .connected {
                Label(connectionLabel, systemImage: "wifi.exclamationmark")
                    .font(.caption).foregroundStyle(Theme.Palette.error)
            }

            scoreboard(state)

            if let frame = state.frame { frameMeta(frame) }

            if let winner = viewModel.winnerName {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill").font(.largeTitle).foregroundStyle(Theme.Palette.teal)
                    Text("\(winner) wins").font(.title2.weight(.semibold))
                }
                Spacer()
            } else if let frame = state.frame {
                Spacer()
                if viewModel.canScore {
                    scoringControls(frame)
                } else if viewModel.mySlot != nil {
                    Text("Your opponent is scoring this break.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("Spectating").font(.footnote).foregroundStyle(.secondary)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error).font(.caption).foregroundStyle(Theme.Palette.error)
            }
        }
        .padding()
    }

    // MARK: Scoreboard

    private func scoreboard(_ state: API.MatchLiveState) -> some View {
        HStack(alignment: .top, spacing: 12) {
            playerCard(state, slot: 0)
            VStack(spacing: 2) {
                Text("\(state.framesWon.first ?? 0)–\(state.framesWon.last ?? 0)")
                    .font(.title.weight(.bold)).monospacedDigit()
                Text("Best of \(state.bestOf)").font(.caption2).foregroundStyle(.secondary)
            }
            playerCard(state, slot: 1)
        }
    }

    private func playerCard(_ state: API.MatchLiveState, slot: Int) -> some View {
        let isStriker = state.frame?.striker == slot
        let frameScore = state.frame?.scores[safe: slot] ?? 0
        return VStack(spacing: 4) {
            Text(state.participants[safe: slot]?.displayName ?? "—")
                .font(.subheadline.weight(isStriker ? .bold : .regular))
                .lineLimit(1)
                .foregroundStyle(isStriker ? Theme.Palette.teal : Theme.Palette.textPrimary)
            Text("\(frameScore)").font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
            if isStriker, let brk = state.frame?.currentBreak, brk.points > 0 {
                Text("break \(brk.points)").font(.caption2).foregroundStyle(Theme.Palette.teal)
            } else {
                Text(" ").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isStriker ? Theme.Palette.teal.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
    }

    private func frameMeta(_ frame: API.FrameState) -> some View {
        HStack(spacing: 12) {
            Text("Frame \(frame.frameNumber)")
            Text("· \(frame.redsRemaining) reds")
            if frame.respottedBlack { Text("· respotted black").foregroundStyle(Theme.Palette.error) }
            if frame.freeBallAvailable { Text("· free ball").foregroundStyle(Theme.Palette.teal) }
        }
        .font(.caption).foregroundStyle(.secondary)
    }

    // MARK: Controls

    @ViewBuilder
    private func scoringControls(_ frame: API.FrameState) -> some View {
        VStack(spacing: 12) {
            let balls: [API.Ball] = [.red, .yellow, .green, .brown, .blue, .pink, .black]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(balls, id: \.self) { ball in
                    Button { viewModel.pot(ball) } label: { ballLabel(ball) }
                        .buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) {
                Button("Foul") { showFoul = true }
                    .buttonStyle(.bordered)
                if frame.freeBallAvailable {
                    Button("Free ball") { viewModel.freeBall() }
                        .buttonStyle(.bordered).tint(Theme.Palette.teal)
                }
                Button("End visit") { viewModel.endVisit() }
                    .buttonStyle(.borderedProminent).tint(Theme.Palette.teal)
                Button { viewModel.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .buttonStyle(.bordered)
            }
            .font(.callout)
        }
        .confirmationDialog("Foul", isPresented: $showFoul, titleVisibility: .visible) {
            ForEach(4...7, id: \.self) { points in
                Button("\(points) away") { viewModel.foul(points: points) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func ballLabel(_ ball: API.Ball) -> some View {
        VStack(spacing: 2) {
            Circle().fill(ballColor(ball))
                .overlay(Circle().strokeBorder(.white.opacity(0.25)))
                .frame(width: 48, height: 48)
            Text("\(ball.points)").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func ballColor(_ ball: API.Ball) -> Color {
        switch ball {
        case .red: return .red
        case .yellow: return .yellow
        case .green: return .green
        case .brown: return .brown
        case .blue: return .blue
        case .pink: return .pink
        case .black: return .black
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
