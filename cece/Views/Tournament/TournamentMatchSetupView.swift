import SwiftUI

/// Best-of chooser shown as a sheet from the bracket. Creates the match (linked
/// to the node) and hands it back via `onStarted`; the bracket then pushes the
/// scoring screen, so finishing the match returns straight to the bracket.
struct TournamentMatchSetupView: View {
    @StateObject private var viewModel: TournamentMatchSetupViewModel
    @Environment(\.dismiss) private var dismiss
    private let onStarted: (Match) -> Void

    init(node: TournamentMatch, dependencies: Dependencies, onStarted: @escaping (Match) -> Void) {
        self.onStarted = onStarted
        _viewModel = StateObject(wrappedValue: TournamentMatchSetupViewModel(
            node: node, dependencies: dependencies
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Участники") {
                    Text(viewModel.player1?.name ?? "—")
                    Text(viewModel.player2?.name ?? "—")
                }
                .foregroundStyle(Theme.Palette.textPrimary)

                Section("Формат") {
                    Picker("Best of", selection: $viewModel.totalFrames) {
                        ForEach(viewModel.frameOptions, id: \.self) { n in
                            Text("Best of \(n)").tag(n)
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(Theme.Palette.error) }
                }
            }
            .navigationTitle("Новый матч")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Начать") {
                        if let match = viewModel.startMatch() { onStarted(match) }
                    }
                    .disabled(!viewModel.canStart)
                }
            }
            .onAppear { viewModel.loadPlayers() }
        }
    }
}
