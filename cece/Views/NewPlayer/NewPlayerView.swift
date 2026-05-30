import SwiftUI

struct NewPlayerView: View {
    @StateObject private var viewModel: NewPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    init(dependencies: Dependencies) {
        _viewModel = StateObject(wrappedValue: NewPlayerViewModel(repository: dependencies.playerRepository))
    }

    var body: some View {
        Form {
            Section("Player") {
                TextField("Name", text: $viewModel.name)
                    .textInputAutocapitalization(.words)
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("New player")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.save() { dismiss() }
                }
                .disabled(!viewModel.canSave)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NewPlayerView(dependencies: PreviewData.dependencies)
    }
}
