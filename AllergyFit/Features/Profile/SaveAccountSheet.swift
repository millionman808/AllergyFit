import SwiftUI
import Supabase

/// Attaches an email and password to an anonymous ("Skip for now") account.
/// Same user id afterwards, so every meal, trigger and plan carries over.
struct SaveAccountSheet: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                if saved { done } else { form }
            }
            .navigationTitle("Save your account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Everything you've logged stays exactly as it is — this just adds a way to sign back in.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                TextField("Email address", text: $email)
                    .textFieldStyle(AFFieldStyle())
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password (at least 6 characters)", text: $password)
                    .textFieldStyle(AFFieldStyle())
                if let error {
                    Text(error).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.danger)
                }
                Button { Task { await save() } } label: {
                    Group {
                        if busy { ProgressView().tint(Theme.Colors.onVolt) }
                        else { Text("Save account").font(Theme.Fonts.headline) }
                    }
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(Theme.Colors.onVolt)
                }
                .disabled(busy || email.isEmpty || password.count < 6)
                .opacity(email.isEmpty || password.count < 6 ? 0.6 : 1)
            }
            .padding(Theme.Metrics.screenPadding)
        }
    }

    private var done: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 52)).foregroundStyle(Theme.Colors.volt)
            Text("Your account is saved.").font(Theme.Fonts.title).foregroundStyle(Theme.Colors.textPrimary)
            Text("Sign in with \(email) on any phone to pick up where you left off.")
                .font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.volt).padding(.top, 6)
        }
        .padding(32)
    }

    @MainActor
    private func save() async {
        busy = true; defer { busy = false }; error = nil
        do {
            _ = try await Backend.client.auth.update(user: UserAttributes(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password))
            // Refresh so isAnonymous flips and the Profile card goes away.
            _ = try? await Backend.client.auth.refreshSession()
            Haptics.success()
            withAnimation { saved = true }
        } catch {
            self.error = AuthView.friendlyAuthMessage(error)
        }
    }
}
