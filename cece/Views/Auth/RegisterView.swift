import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var session: Session
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var handle = ""
    @State private var errorMessage: String?
    @State private var isBusy = false

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
            } header: {
                Text("Account")
            } footer: {
                Text("At least 8 characters.")
            }

            Section {
                TextField("Display name", text: $displayName)
                TextField("Handle", text: $handle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Profile")
            } footer: {
                Text("Handle: lowercase letters, digits and _, 3–20 chars, starts with a letter.")
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(Theme.Palette.error) }
            }

            Section {
                Button("Create account") { Task { await register() } }
                    .disabled(!canSubmit || isBusy)
            }
        }
        .navigationTitle("Create account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canSubmit: Bool {
        AuthValidation.isValidEmail(email)
            && AuthValidation.isValidPassword(password)
            && AuthValidation.isValidDisplayName(displayName)
            && AuthValidation.isValidHandle(handle)
    }

    private func register() async {
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil
        do {
            // On success the session flips to .signedIn and the gate swaps the root.
            try await session.register(
                email: email,
                password: password,
                displayName: displayName,
                handle: handle
            )
        } catch {
            errorMessage = AuthErrorText.message(error)
        }
    }
}
