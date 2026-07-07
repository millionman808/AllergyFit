import SwiftUI
import AuthenticationServices
import Supabase

struct AuthView: View {
    @EnvironmentObject var session: SessionStore
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningUp = false
    @State private var errorMessage: String?
    @State private var isBusy = false

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("AllergyFit")
                        .font(Theme.Fonts.stat(44))
                        .foregroundStyle(Theme.Colors.volt)
                    Text("Train hard. Eat safe.")
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                VStack(spacing: Theme.Metrics.spacing) {
                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task { await handleApple(result) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    divider

                    TextField("Email", text: $email)
                        .textFieldStyle(AFFieldStyle())
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                        .textFieldStyle(AFFieldStyle())

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.danger)
                    }

                    Button {
                        Task { await submitEmail() }
                    } label: {
                        Text(isSigningUp ? "Create Account" : "Sign In")
                            .font(Theme.Fonts.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Theme.Colors.volt)
                            .foregroundStyle(Theme.Colors.onVolt)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isBusy || email.isEmpty || password.isEmpty)
                    .opacity(isBusy ? 0.6 : 1)

                    Button {
                        isSigningUp.toggle()
                        errorMessage = nil
                    } label: {
                        Text(isSigningUp ? "Have an account? Sign in" : "New here? Create an account")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Button {
                        session.isDemo = true
                    } label: {
                        Label("View demo", systemImage: "eye.fill")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.volt)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, Theme.Metrics.screenPadding)

                Spacer(minLength: 32)
            }
        }
    }

    private var divider: some View {
        HStack {
            Rectangle().fill(Theme.Colors.surfaceRaised).frame(height: 1)
            Text("or").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textTertiary)
            Rectangle().fill(Theme.Colors.surfaceRaised).frame(height: 1)
        }
    }

    // MARK: - Actions

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        guard case .success(let auth) = result,
              let credential = auth.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            errorMessage = "Apple sign-in failed. Try again."
            return
        }
        do {
            try await Backend.client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: token)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitEmail() async {
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil
        do {
            if isSigningUp {
                try await Backend.client.auth.signUp(email: email, password: password)
            } else {
                try await Backend.client.auth.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AFFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(Theme.Fonts.body)
            .padding(14)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(Theme.Colors.textPrimary)
    }
}
