import SwiftUI

/// Match-launch screen reached by tapping a ready bracket slot. Picks the
/// best-of format, creates the match (linking it to the bracket node), and opens
/// the live scoring screen. Resumes an already-started match instead.
struct TournamentMatchSetupView: View {
    @StateObject private var viewModel: TournamentMatchSetupViewModel
    @State private var activeMatch: Match?
    private let dependencies: Dependencies

    init(node: TournamentMatch, dependencies: Dependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: TournamentMatchSetupViewModel(
            node: node, dependencies: dependencies
        ))
    }

    var body: some View {
        Form {
            Section("Участники") {
                Text(viewModel.player1?.name ?? "—")
                Text(viewModel.player2?.name ?? "—")
            }
            .foregroundStyle(Theme.Palette.textPrimary)

            if viewModel.existingMatch == nil {
                Section("Формат") {
                    Picker("Best of", selection: $viewModel.totalFrames) {
                        ForEach(viewModel.frameOptions, id: \.self) { n in
                            Text("Best of \(n)").tag(n)
                        }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Матч")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.existingMatch == nil ? "Начать" : "Продолжить") {
                    activeMatch = viewModel.startMatch()
                }
                .disabled(viewModel.existingMatch == nil && !viewModel.canStart)
            }
        }
        .navigationDestination(item: $activeMatch) { match in
            MatchPlayView(viewModel: dependencies.liveMatchViewModel(for: match))
        }
        .onAppear { viewModel.loadPlayers() }
    }
}
