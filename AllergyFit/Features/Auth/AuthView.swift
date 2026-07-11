import SwiftUI
import AuthenticationServices
import Supabase
import GoogleSignIn

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

                    // Continue with Google
                    Button {
                        Task { await handleGoogle() }
                    } label: {
                        HStack(spacing: 10) {
                            GoogleGlyph()
                                .frame(width: 20, height: 20)
                            Text("Continue with Google")
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Color(hex: 0x1F1F1F))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isBusy)
                    .opacity(isBusy ? 0.6 : 1)

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

    /// Native Google Sign-In: Google's own sheet (no "supabase.co" browser prompt),
    /// then the resulting ID token is exchanged with Supabase.
    @MainActor
    private func handleGoogle() async {
        guard let root = Self.rootViewController else {
            errorMessage = "Couldn't start Google sign-in. Try again."
            return
        }
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google didn't return a sign-in token. Try again."
                return
            }
            try await Backend.client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
            )
        } catch {
            // User closing Google's sheet isn't an error worth showing.
            let ns = error as NSError
            if ns.domain == kGIDSignInErrorDomain, ns.code == GIDSignInError.canceled.rawValue { return }
            errorMessage = error.localizedDescription
        }
    }

    private static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
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

/// Google's four-color "G", drawn so we don't need to bundle the brand asset.
struct GoogleGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let lw = s * 0.22
            ZStack {
                Circle()
                    .trim(from: 0.0, to: 0.25)
                    .stroke(Color(hex: 0x4285F4), style: .init(lineWidth: lw))   // blue
                Circle()
                    .trim(from: 0.25, to: 0.5)
                    .stroke(Color(hex: 0x34A853), style: .init(lineWidth: lw))   // green
                Circle()
                    .trim(from: 0.5, to: 0.75)
                    .stroke(Color(hex: 0xFBBC05), style: .init(lineWidth: lw))   // yellow
                Circle()
                    .trim(from: 0.75, to: 1.0)
                    .stroke(Color(hex: 0xEA4335), style: .init(lineWidth: lw))   // red
                // The horizontal bar of the "G"
                Rectangle()
                    .fill(Color(hex: 0x4285F4))
                    .frame(width: s * 0.5, height: lw)
                    .offset(x: s * 0.25, y: 0)
            }
            .rotationEffect(.degrees(-45))
        }
        .aspectRatio(1, contentMode: .fit)
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
