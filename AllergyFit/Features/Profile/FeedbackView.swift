import SwiftUI
import UIKit
import Supabase

/// "Tell us what you think." One text box, one tap. Feedback lands in the
/// `feedback` table (insert-only for users) with just enough device context
/// to reproduce a problem — and an email only if they ask for a reply.
struct FeedbackView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var kind: Kind = .idea
    @State private var message = ""
    @State private var wantsReply = false
    @State private var sending = false
    @State private var sent = false
    @State private var error: String?
    @FocusState private var focused: Bool

    static let supportEmail = "support@schafersites.com"

    enum Kind: String, CaseIterable, Identifiable {
        case idea, problem, other
        var id: String { rawValue }
        var label: String {
            switch self { case .idea: "Idea"; case .problem: "Problem"; case .other: "Other" }
        }
        var icon: String {
            switch self { case .idea: "lightbulb.fill"; case .problem: "exclamationmark.triangle.fill"; case .other: "bubble.left.fill" }
        }
        var prompt: String {
            switch self {
            case .idea: "What would make SafeFuel better for you?"
            case .problem: "What went wrong? Where were you in the app?"
            case .other: "What's on your mind?"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                if sent { thanks } else { form }
            }
            .navigationTitle("Feedback")
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
            VStack(alignment: .leading, spacing: 18) {
                Text("Tell us what you think")
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Every message is read by the person who builds this app.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)

                HStack(spacing: 8) {
                    ForEach(Kind.allCases) { k in
                        Button {
                            Haptics.tap(); kind = k
                        } label: {
                            Label(k.label, systemImage: k.icon)
                                .font(Theme.Fonts.caption.weight(.semibold))
                                .foregroundStyle(kind == k ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(kind == k ? Theme.Colors.volt : Theme.Colors.surface, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                ZStack(alignment: .topLeading) {
                    if message.isEmpty {
                        Text(kind.prompt)
                            .font(Theme.Fonts.body)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .padding(.horizontal, 5).padding(.vertical, 8)
                    }
                    TextEditor(text: $message)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 150)
                        .focused($focused)
                }
                .padding(10)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Toggle(isOn: $wantsReply) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("I'd like a reply").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                        Text(wantsReply && session.session?.user.email != nil
                             ? "We'll write to \(session.session?.user.email ?? "")."
                             : "Shares your account email with us.")
                            .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .tint(Theme.Colors.volt)
                .card()

                if let error {
                    Text(error).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.danger)
                }

                Button {
                    Task { await send() }
                } label: {
                    Group {
                        if sending { ProgressView().tint(Theme.Colors.onVolt) }
                        else { Text("Send").font(Theme.Fonts.headline) }
                    }
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(canSend ? Theme.Colors.volt : Theme.Colors.surfaceRaised,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(Theme.Colors.onVolt)
                }
                .disabled(!canSend || sending)
                .pressable()

                Button {
                    openURL(URL(string: "mailto:\(Self.supportEmail)?subject=SafeFuel%20feedback")!)
                } label: {
                    Text("Or email \(Self.supportEmail)")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(Theme.Metrics.screenPadding)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { focused = true }
    }

    private var thanks: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54)).foregroundStyle(Theme.Colors.volt)
            Text("Got it — thank you.").font(Theme.Fonts.title).foregroundStyle(Theme.Colors.textPrimary)
            Text(wantsReply ? "We'll reply to your email." : "Your note is on its way to the person who builds this.")
                .font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.volt).padding(.top, 8)
        }
        .padding(32)
    }

    private var canSend: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private struct Row: Encodable {
        let user_id: UUID
        let kind: String
        let message: String
        let reply_email: String?
        let app_version: String
        let build: String
        let device: String
        let os_version: String
    }

    @MainActor
    private func send() async {
        guard let userId = session.session?.user.id else {
            error = "Sign in to send feedback, or email us instead."; return
        }
        sending = true; defer { sending = false }; error = nil
        let info = Bundle.main.infoDictionary ?? [:]
        let row = Row(
            user_id: userId,
            kind: kind.rawValue,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            reply_email: wantsReply ? session.session?.user.email : nil,
            app_version: info["CFBundleShortVersionString"] as? String ?? "?",
            build: info["CFBundleVersion"] as? String ?? "?",
            device: UIDevice.current.model,
            os_version: UIDevice.current.systemVersion)
        do {
            try await Backend.client.from("feedback").insert(row).execute()
            Haptics.success()
            withAnimation { sent = true }
        } catch {
            self.error = "Couldn't send right now. Check your connection, or use the email link below."
        }
    }
}
