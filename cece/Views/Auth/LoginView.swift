import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: Session
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isBusy = false

    var body: some View {
        Form {
            Section("Account") {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(Theme.Palette.error) }
            }

            Section {
                Button("Log in") { Task { await logIn() } }
                    .disabled(!canSubmit || isBusy)
                NavigationLink("Create account") { RegisterView() }
            }
        }
        .navigationTitle("Log in")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canSubmit: Bool {
        AuthValidation.isValidEmail(email) && !password.isEmpty
    }

    private func logIn() async {
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil
        do {
            try await session.login(email: email, password: password)
        } catch {
            errorMessage = AuthErrorText.message(error)
        }
    }
}
