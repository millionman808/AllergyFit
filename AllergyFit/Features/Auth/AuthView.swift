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

/// Google's four-color "G" — traced from the official 18×18 logo paths so it
/// matches the real brand mark without bundling an image asset.
struct GoogleGlyph: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 18
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

            var blue = Path()
            blue.move(to: p(17.64, 9.2045))
            blue.addCurve(to: p(17.4764, 7.3636), control1: p(17.64, 8.5664), control2: p(17.5827, 7.9527))
            blue.addLine(to: p(9, 7.3636))
            blue.addLine(to: p(9, 10.845))
            blue.addLine(to: p(13.8436, 10.845))
            blue.addCurve(to: p(12.0477, 13.5614), control1: p(13.635, 11.97), control2: p(13.0009, 12.9232))
            blue.addLine(to: p(12.0477, 15.8195))
            blue.addLine(to: p(14.9564, 15.8195))
            blue.addCurve(to: p(17.64, 9.2045), control1: p(16.6582, 14.2527), control2: p(17.64, 11.9455))
            blue.closeSubpath()

            var green = Path()
            green.move(to: p(9, 18))
            green.addCurve(to: p(14.9564, 15.8195), control1: p(11.43, 18), control2: p(13.4673, 17.1941))
            green.addLine(to: p(12.0477, 13.5614))
            green.addCurve(to: p(9, 14.4205), control1: p(11.2418, 14.1014), control2: p(10.2109, 14.4205))
            green.addCurve(to: p(3.9641, 10.71), control1: p(6.6559, 14.4205), control2: p(4.6718, 12.8373))
            green.addLine(to: p(0.9573, 10.71))
            green.addLine(to: p(0.9573, 13.0418))
            green.addCurve(to: p(9, 18), control1: p(2.4382, 15.9832), control2: p(5.4818, 18))
            green.closeSubpath()

            var yellow = Path()
            yellow.move(to: p(3.9641, 10.71))
            yellow.addCurve(to: p(3.6818, 9), control1: p(3.7841, 10.17), control2: p(3.6818, 9.5932))
            yellow.addCurve(to: p(3.9641, 7.29), control1: p(3.6818, 8.4068), control2: p(3.7841, 7.83))
            yellow.addLine(to: p(3.9641, 4.9582))
            yellow.addLine(to: p(0.9573, 4.9582))
            yellow.addCurve(to: p(0, 9), control1: p(0.3477, 6.1732), control2: p(0, 7.5477))
            yellow.addCurve(to: p(0.9573, 13.0418), control1: p(0, 10.4523), control2: p(0.3477, 11.8268))
            yellow.closeSubpath()

            var red = Path()
            red.move(to: p(9, 3.5795))
            red.addCurve(to: p(12.4405, 4.9255), control1: p(10.3214, 3.5795), control2: p(11.5077, 4.0336))
            red.addLine(to: p(15.0218, 2.3441))
            red.addCurve(to: p(9, 0), control1: p(13.4632, 0.8918), control2: p(11.4259, 0))
            red.addCurve(to: p(0.9573, 4.9582), control1: p(5.4818, 0), control2: p(2.4382, 2.0168))
            red.addLine(to: p(3.9641, 7.29))
            red.addCurve(to: p(9, 3.5795), control1: p(4.6718, 5.1627), control2: p(6.6559, 3.5795))
            red.closeSubpath()

            context.fill(blue, with: .color(Color(hex: 0x4285F4)))
            context.fill(green, with: .color(Color(hex: 0x34A853)))
            context.fill(yellow, with: .color(Color(hex: 0xFBBC05)))
            context.fill(red, with: .color(Color(hex: 0xEA4335)))
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
