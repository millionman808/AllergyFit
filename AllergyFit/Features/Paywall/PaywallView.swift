import SwiftUI
import RevenueCat

/// Old Money Heritage Athletic Club Membership Paywall.
/// Single-screen, zero scrolling, 3-second hard lock on top-corner dismiss,
/// 3-day free trial member pass, and dark green & burnished brass palette.
struct PaywallView: View {
    var source: String = "unknown"
    var onDismiss: (() -> Void)? = nil

    @EnvironmentObject var purchases: PurchasesManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selected: Package?
    @State private var busy = false
    @State private var canDismiss = false

    private let privacyURL = URL(string: "https://safefuel.schafersites.com/privacy")!
    private let termsURL = URL(string: "https://safefuel.schafersites.com/terms")!

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
                .onAppear { AdAttribution.logPaywallView(source: source) }

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 6)
                    .padding(.horizontal, 22)

                Spacer(minLength: 4)

                clubCardHero
                    .padding(.horizontal, 20)

                Spacer(minLength: 8)

                privilegesList
                    .padding(.horizontal, 20)

                Spacer(minLength: 8)

                membershipTierCard
                    .padding(.horizontal, 20)

                if let err = purchases.purchaseError {
                    Text(err)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.danger)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 8)

                ctaSection
                    .padding(.horizontal, 20)

                Spacer(minLength: 4)

                footerSection
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await purchases.loadOfferings()
            selected = preferredPackage

            // 3-second hard lock before close button appears
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                canDismiss = true
            }
        }
    }

    // MARK: - Header & 3-Second Delayed Close

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("CLUB PRIVILEGES")
                    .font(Theme.Fonts.clubTag(10))
                    .tracking(2.0)
            }
            .foregroundStyle(Theme.Colors.antiqueBrass)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.Colors.antiqueBrass.opacity(0.14), in: Capsule())
            .overlay(
                Capsule().strokeBorder(Theme.Colors.antiqueBrass.opacity(0.4), lineWidth: 1)
            )

            Spacer()

            if canDismiss {
                Button {
                    Haptics.tap()
                    closePaywall()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Theme.Colors.surface, in: Circle())
                        .overlay(
                            Circle().strokeBorder(Theme.Colors.parchmentBorder, lineWidth: 1)
                        )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
                .accessibilityLabel("Close and use free version")
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
        }
        .frame(height: 36)
    }

    // MARK: - Metal Club Card Hero

    private var clubCardHero: some View {
        VStack(spacing: 4) {
            Text("SafeFuel Athletic Club")
                .font(Theme.Fonts.display(26))
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Full Member Admission & Allergen Quarantine Protocol")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Privileges Grid (Compact Single-Screen)

    private var privilegesList: some View {
        VStack(spacing: 8) {
            privilegeRow(icon: "shield.checkerboard",
                         title: "Zero-Trace Allergen Shield",
                         desc: "AI food & label screening with strict trigger quarantine.")
            privilegeRow(icon: "bolt.heart.fill",
                         title: "Dynamic Smartwatch Calorie Sync",
                         desc: "Apple Watch, Fitbit, Garmin & Strava workout balancing.")
            privilegeRow(icon: "gauge.with.needle.fill",
                         title: "Daily Nutrition & Fuel Score",
                         desc: "0–100 recovery index & micronutrient adherence breakdown.")
            privilegeRow(icon: "drop.fill",
                         title: "Hydration & Strength Ledger",
                         desc: "Multi-beverage hydration tracking and lifted volume comparison.")
            privilegeRow(icon: "fork.knife",
                         title: "Bespoke Chef Meal Plans",
                         desc: "Weekly recipes strictly built around your personal triggers.")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.Colors.parchmentBorder, lineWidth: 1)
        )
    }

    private func privilegeRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.racingGreen.opacity(0.10))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.racingGreen)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(desc)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Membership Card Pricing

    private var membershipTierCard: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text("3-DAY HONORARY GUEST PASS")
                        .font(Theme.Fonts.clubTag(9))
                        .tracking(1.5)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.Colors.racingGreen, in: Capsule())

                Spacer()

                Text("BEST VALUE")
                    .font(Theme.Fonts.clubTag(10))
                    .tracking(1.5)
                    .foregroundStyle(Theme.Colors.antiqueBrass)
            }

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("$0.00 Due Today")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Complimentary 3 days access. Cancel anytime.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("$39.99/yr")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.Colors.racingGreen)
                    Text("$3.33 / month")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        .padding(12)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.Colors.antiqueBrass.opacity(0.8), lineWidth: 1.5)
        )
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 6) {
            Button {
                Task {
                    busy = true
                    if let pkg = selected {
                        await purchases.purchase(pkg)
                    } else if let fallback = purchases.packages.first {
                        await purchases.purchase(fallback)
                    }
                    busy = false
                    if purchases.isPremium {
                        closePaywall()
                    }
                }
            } label: {
                Group {
                    if busy {
                        ProgressView().tint(Theme.Colors.onVolt)
                    } else {
                        HStack(spacing: 8) {
                            Text("Claim 3-Day Honorary Pass")
                                .font(Theme.Fonts.headline)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                    }
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.Colors.racingGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.Colors.antiqueBrass.opacity(0.35), lineWidth: 1)
                )
            }
            .disabled(busy)
            .pressable()

            Text("Annual billing begins after 3 days. Cancel anytime in Apple Settings.")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 16) {
            Button("Restore Purchases") {
                Task {
                    busy = true
                    await purchases.restore()
                    busy = false
                    if purchases.isPremium { closePaywall() }
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.Colors.textSecondary)

            Text("•").font(.system(size: 10)).foregroundStyle(Theme.Colors.textTertiary)

            Button("Privacy Policy") { openURL(privacyURL) }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Colors.textTertiary)

            Text("•").font(.system(size: 10)).foregroundStyle(Theme.Colors.textTertiary)

            Button("Terms of Use") { openURL(termsURL) }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }

    private func closePaywall() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    private var preferredPackage: Package? {
        purchases.packages.first { $0.packageType == .annual } ?? purchases.packages.first
    }
}
