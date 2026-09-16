import SwiftUI
import RevenueCat

/// High-converting, single-screen paywall with a 3-second hard lock.
/// Fits entirely on one screen without scrolling on any device.
/// Shows all features, 3-day free trial pricing, and reveals an 'X' button
/// in the top corner after 3 seconds for free version access.
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
                    .padding(.horizontal, 20)

                Spacer(minLength: 4)

                headline
                    .padding(.horizontal, 20)

                Spacer(minLength: 8)

                featuresCard
                    .padding(.horizontal, 18)

                Spacer(minLength: 8)

                pricingCard
                    .padding(.horizontal, 18)

                if let err = purchases.purchaseError {
                    Text(err)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Colors.danger)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 8)

                ctaSection
                    .padding(.horizontal, 18)

                Spacer(minLength: 4)

                footerSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await purchases.loadOfferings()
            selected = preferredPackage

            // 3-second hard paywall: the X button remains hidden for 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                canDismiss = true
            }
        }
    }

    // MARK: - Header & 3-Second Close Button

    private var topBar: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("PRO ACCESS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Theme.Colors.volt)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.Colors.volt.opacity(0.14), in: Capsule())

            Spacer()

            if canDismiss {
                Button {
                    Haptics.tap()
                    closePaywall()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Theme.Colors.surface, in: Circle())
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                .accessibilityLabel("Close and use free version")
            } else {
                Color.clear
                    .frame(width: 32, height: 32)
            }
        }
        .frame(height: 36)
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(spacing: 4) {
            Text("Unlock SafeFuel Pro")
                .font(Theme.Fonts.stat(28))
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text("Train at your peak. Eat with 100% confidence.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Features List (Compact Single-Screen Layout)

    private var featuresCard: some View {
        VStack(spacing: 9) {
            featureRow(icon: "shield.checkerboard",
                       title: "100% Allergen Shield",
                       desc: "Instant AI meal scans & zero-cross-contamination flags.")
            featureRow(icon: "bolt.heart.fill",
                       title: "Dynamic Workout Fueling",
                       desc: "Auto-syncs Apple Watch, Fitbit, Garmin & Strava calories.")
            featureRow(icon: "gauge.with.needle.fill",
                       title: "Daily Fuel & Recovery Score",
                       desc: "Bevel-inspired 0–100 nutrition score and macro balance.")
            featureRow(icon: "drop.fill",
                       title: "Smart Hydration & Strength Lifts",
                       desc: "Multi-beverage logging & sets/reps volume tracking.")
            featureRow(icon: "fork.knife",
                       title: "Custom Safe Meal Plans",
                       desc: "Weekly recipes strictly built around your personal triggers.")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.volt.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.volt)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(desc)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Pricing & 3-Day Free Trial

    private var pricingCard: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text("3-DAY FREE TRIAL INCLUDED")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(Theme.Colors.onVolt)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.Colors.volt, in: Capsule())

                Spacer()

                Text("SAVE 60%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.volt)
            }

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("$0.00 Due Today")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Try full Pro free for 3 days. Cancel anytime.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("$39.99/yr")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.Colors.volt)
                    Text("$3.33 / month")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        .padding(12)
        .background(Theme.Colors.volt.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.Colors.volt.opacity(0.8), lineWidth: 1.5)
        )
    }

    // MARK: - CTA Button

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
                            Text("Start 3-Day Free Trial")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                }
                .foregroundStyle(Theme.Colors.onVolt)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .disabled(busy)
            .pressable()

            Text("Renews at $39.99/year after 3 days. Cancel anytime in App Store.")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Footer Links

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

            Text("•")
                .font(.system(size: 10))
                .foregroundStyle(Theme.Colors.textTertiary)

            Button("Privacy Policy") { openURL(privacyURL) }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Colors.textTertiary)

            Text("•")
                .font(.system(size: 10))
                .foregroundStyle(Theme.Colors.textTertiary)

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
