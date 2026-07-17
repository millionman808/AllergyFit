import SwiftUI

/// Shown when the backend can't be reached. This screen ships inside the app
/// binary — it does NOT depend on Supabase — so an outage can't take down the
/// very screen that explains the outage. Auto-retries every 30s and offers a
/// manual retry plus a support contact.
struct OfflineView: View {
    let retry: () async -> Void

    @State private var secondsLeft = 30
    @State private var isRetrying = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let supportEmail = "support@allergyfit.app"

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Theme.Colors.caution)

                Text("AllergyFit is temporarily offline")
                    .font(Theme.Fonts.title)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Your data is safe — nothing is lost. We just can't reach our servers right now.")
                    .font(Theme.Fonts.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.horizontal, 12)

                Text(isRetrying ? "Reconnecting…" : "Retrying in \(secondsLeft)s")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.top, 4)

                Button {
                    Task { await runRetry() }
                } label: {
                    HStack(spacing: 8) {
                        if isRetrying { ProgressView().tint(Theme.Colors.onVolt) }
                        Text(isRetrying ? "Trying…" : "Try again")
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.onVolt)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(isRetrying)
                .pressable()
                .padding(.top, 8)

                Spacer()

                Link(destination: URL(string: "mailto:\(supportEmail)")!) {
                    Text("Contact support")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.volt)
                }
            }
            .padding(28)
        }
        .onReceive(timer) { _ in
            guard !isRetrying else { return }
            if secondsLeft > 1 {
                secondsLeft -= 1
            } else {
                Task { await runRetry() }
            }
        }
    }

    private func runRetry() async {
        guard !isRetrying else { return }
        isRetrying = true
        await retry()
        isRetrying = false
        secondsLeft = 30
    }
}
