import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var session: Session
    @Environment(\.modelContext) private var modelContext

    #if DEBUG
    @State private var showResetConfirmation = false
    #endif

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Form {
                if let user = session.currentUser {
                    Section("Account") {
                        LabeledContent("Signed in as", value: "@\(user.handle)")
                        Button(role: .destructive) { session.logout() } label: {
                            Text("Log out")
                        }
                    }
                }

                Section("About") {
                    LabeledContent("App", value: "ce·ce")
                    LabeledContent("Version", value: appVersion)
                }

                #if DEBUG
                Section("Developer") {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("Reset all data", systemImage: "trash")
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
            #if DEBUG
            .confirmationDialog(
                "Reset all data?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    resetAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all players and matches. This action cannot be undone.")
            }
            #endif
        }
    }

    #if DEBUG
    /// Wipes every SwiftData model. Debug-only developer utility.
    /// Matches are deleted first so their cascade rules clean up frames/breaks
    /// before the player records they reference are removed.
    private func resetAllData() {
        do {
            try modelContext.delete(model: Match.self)
            try modelContext.delete(model: Player.self)
            try modelContext.delete(model: Frame.self)
            try modelContext.delete(model: Break.self)
            try modelContext.save()
        } catch {
            print("Reset failed: \(error)")
        }
    }
    #endif
}

#Preview {
    SettingsView()
        .environmentObject(PreviewData.session)
        .modelContainer(PreviewData.container)
}
