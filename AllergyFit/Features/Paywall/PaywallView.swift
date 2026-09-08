import SwiftUI
import RevenueCat

/// Shown once, right after onboarding. Uses the trial-timeline pattern — people
/// convert far better when they can see exactly when (and whether) they'll be
/// charged than from a bare price list.
///
/// Deliberately dismissible: allergen checking is a safety feature, so the app
/// stays usable without a subscription.
struct PaywallView: View {
    @EnvironmentObject var purchases: PurchasesManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selected: Package?
    @State private var busy = false

    private let privacyURL = URL(string: "https://allergyfit-app.web.app/privacy.html")!

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    closeRow
                    headline
                    timeline
                    plans
                    if let err = purchases.purchaseError {
                        Text(err)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.danger)
                            .frame(maxWidth: .infinity)
                    }
                    cta
                    smallprint
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
        }
        .task {
            await purchases.loadOfferings()
            selected = preferredPackage
        }
    }

    private var closeRow: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(width: 34, height: 34)
                    .background(Theme.Colors.surface, in: Circle())
            }
        }
        .padding(.top, 10)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Eat without\nsecond-guessing.")
                .font(Theme.Fonts.stat(32))
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Unlimited AI meal checks, safe recipes and weekly plans — built around your triggers.")
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineRow("lock.open.fill", "Today", "Full access — every feature unlocked.", first: true)
            timelineRow("bell.fill", "In 2 days", "We'll remind you before the trial ends.")
            timelineRow("checkmark.circle.fill", "In 3 days", "Your plan begins. Cancel any time before.", last: true)
        }
        .padding(16)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func timelineRow(_ icon: String, _ title: String, _ body: String,
                             first: Bool = false, last: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(first ? Color.clear : Theme.Colors.volt.opacity(0.35))
                    .frame(width: 2, height: 10)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.onVolt)
                    .frame(width: 28, height: 28)
                    .background(Theme.Colors.volt, in: Circle())
                Rectangle()
                    .fill(last ? Color.clear : Theme.Colors.volt.opacity(0.35))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                Text(body).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 10)
            .padding(.bottom, last ? 0 : 14)
            Spacer(minLength: 0)
        }
        .frame(minHeight: last ? 0 : 62, alignment: .top)
    }

    @ViewBuilder private var plans: some View {
        if purchases.isLoadingOfferings {
            ProgressView().tint(Theme.Colors.volt)
                .frame(maxWidth: .infinity).padding(.vertical, 26)
        } else if purchases.packages.isEmpty {
            VStack(spacing: 10) {
                planCard(title: "Annual", price: "$39.99 / year",
                         note: "3-day free trial · best value", featured: true)
                planCard(title: "Monthly", price: "$7.99 / month",
                         note: "Cancel any time", featured: false)
            }
        } else {
            VStack(spacing: 10) {
                ForEach(purchases.packages, id: \.identifier) { pkg in
                    Button { Haptics.tap(); selected = pkg } label: {
                        planCard(title: label(for: pkg),
                                 price: pkg.storeProduct.localizedPriceString,
                                 note: note(for: pkg),
                                 featured: selected?.identifier == pkg.identifier)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func planCard(title: String, price: String, note: String, featured: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                Text(note).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Text(price)
                .font(Theme.Fonts.headline)
                .foregroundStyle(featured ? Theme.Colors.volt : Theme.Colors.textPrimary)
        }
        .padding(16)
        .background(featured ? Theme.Colors.volt.opacity(0.10) : Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(featured ? Theme.Colors.volt : Color.clear, lineWidth: 1.5))
    }

    private var cta: some View {
        VStack(spacing: 10) {
            Button {
                guard let pkg = selected else { dismiss(); return }
                Task {
                    busy = true
                    await purchases.purchase(pkg)
                    busy = false
                    if purchases.isPremium { dismiss() }
                }
            } label: {
                Group {
                    if busy { ProgressView().tint(Theme.Colors.onVolt) }
                    else { Text(ctaTitle) }
                }
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.onVolt)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(busy)
            .pressable()

            Button("Maybe later") { dismiss() }
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private var ctaTitle: String {
        guard let pkg = selected else { return "Continue" }
        return pkg.storeProduct.introductoryDiscount != nil ? "Start free trial" : "Continue"
    }

    private var smallprint: some View {
        VStack(spacing: 8) {
            Button("Restore purchases") {
                Task { await purchases.restore(); if purchases.isPremium { dismiss() } }
            }
            .font(Theme.Fonts.caption)
            .foregroundStyle(Theme.Colors.textSecondary)

            Text("Billed through your Apple account. Cancel any time in Settings. Allergen checks stay available without a subscription.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Privacy Policy") { openURL(privacyURL) }
                .font(.system(size: 11))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private var preferredPackage: Package? {
        purchases.packages.first { $0.packageType == .annual } ?? purchases.packages.first
    }
    private func label(for pkg: Package) -> String {
        switch pkg.packageType {
        case .annual: return "Annual"
        case .monthly: return "Monthly"
        case .lifetime: return "Lifetime"
        default: return pkg.storeProduct.localizedTitle
        }
    }
    private func note(for pkg: Package) -> String {
        if pkg.storeProduct.introductoryDiscount != nil { return "3-day free trial · best value" }
        switch pkg.packageType {
        case .monthly: return "Cancel any time"
        case .lifetime: return "One payment, yours for good"
        default: return "Cancel any time"
        }
    }
}
