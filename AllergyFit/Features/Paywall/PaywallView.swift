import SwiftUI
import RevenueCat

/// Paywall: serif headline, Free vs. Premium table, three plan cards and a
/// CONTINUE button. Every price, period and trial comes from the App Store
/// through RevenueCat, so each card buys exactly the product it shows, and
/// "free trial" only appears for Apple IDs that can still get one.
struct PaywallView: View {
    var source: String = "gate"

    @EnvironmentObject var purchases: PurchasesManager
    @EnvironmentObject var session: SessionStore
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    /// RevenueCat package identifier of the selected card (yearly by default).
    @State private var selectedID: String?
    @State private var busy = false
    @State private var showAccountMenu = false
    @State private var confirmDelete = false
    @State private var confirmAnonSignOut = false
    @State private var showSaveAccount = false
    @State private var accountError: String?

    private let privacyURL = URL(string: "https://safefuel.schafersites.com/privacy")!
    private let termsURL = URL(string: "https://safefuel.schafersites.com/terms")!

    // Free vs Premium Comparison Matrix Items
    struct ComparisonFeature: Identifiable {
        let id = UUID()
        let name: String
        let isFree: Bool
        let isPremium: Bool
    }

    private let features: [ComparisonFeature] = [
        ComparisonFeature(name: "Barcode scanner", isFree: true, isPremium: true),
        ComparisonFeature(name: "AI Smart Tracking", isFree: false, isPremium: true),
        ComparisonFeature(name: "Safe Recipe Ideas", isFree: false, isPremium: true),
        ComparisonFeature(name: "Adjust Your Macros & Calories", isFree: false, isPremium: true),
        ComparisonFeature(name: "Create Your Own Meals", isFree: false, isPremium: true),
        ComparisonFeature(name: "Allergen Cross-Check & Warnings", isFree: false, isPremium: true)
    ]

    /// First name if we know it; otherwise the headline just leaves it out.
    var userName: String? {
        guard let name = UserDefaults.standard.string(forKey: "displayName"),
              let first = name.split(separator: " ").first, !first.isEmpty else { return nil }
        return String(first)
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Navigation Bar
                topBar

                ScrollView {
                    VStack(spacing: 20) {
                        // Serif Headline
                        headlineSection

                        // Comparison Table (Free vs Premium)
                        comparisonTable

                        // Trial ribbon (only when this Apple ID can still get the trial)
                        if let days = trialDays(annualPackage) {
                            promoBanner("\(days) days free on the yearly plan")
                        }

                        // Plan cards, straight from the App Store
                        subscriptionTiersSection

                        // Error message if any
                        if let err = purchases.purchaseError ?? accountError {
                            Text(err)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.danger)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 190) // Clearance for the fixed checkout bar
                }
            }

            // Fixed Bottom Bar with CONTINUE CTA and Links
            VStack {
                Spacer()
                bottomCheckoutBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            AdAttribution.logPaywallView(source: source)
        }
        .task {
            if purchases.packages.isEmpty {
                await purchases.loadOfferings()
            }
            if selectedID == nil { selectedID = (annualPackage ?? orderedPackages.first)?.identifier }
        }
        .onChange(of: purchases.packages.count) { _ in
            if selectedID == nil { selectedID = (annualPackage ?? orderedPackages.first)?.identifier }
        }
        .confirmationDialog("Account", isPresented: $showAccountMenu, titleVisibility: .hidden) {
            if session.isAnonymous {
                Button("Save my account") { showSaveAccount = true }
            }
            Button("Sign out") {
                if session.isAnonymous { confirmAnonSignOut = true }
                else { Task { await session.signOut() } }
            }
            Button("Delete account", role: .destructive) { confirmDelete = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(accountLine)
        }
        .confirmationDialog("Sign out without saving?", isPresented: $confirmAnonSignOut, titleVisibility: .visible) {
            Button("Save my account first") { showSaveAccount = true }
            Button("Sign out and lose my data", role: .destructive) { Task { await session.signOut() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You skipped creating an account, so there's no way to sign back in.")
        }
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                Task {
                    accountError = nil
                    do { try await session.deleteAccount() }
                    catch { accountError = "Couldn't delete right now. Try again, or email support@schafersites.com." }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your profile, triggers, meals and plans.")
        }
        .sheet(isPresented: $showSaveAccount) {
            SaveAccountSheet()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                showAccountMenu = true
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 40, height: 40)
            }

            Spacer()

            // The launch gate can't be closed (there's nothing behind it), so
            // the X only shows when the paywall was opened from somewhere.
            if source != "gate" {
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Close")
            } else {
                Button("Restore") {
                    Task { busy = true; await purchases.restore(); busy = false }
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var accountLine: String {
        if session.isAnonymous { return "You're using SafeFuel without an account." }
        if let email = session.session?.user.email { return "Signed in as \(email)" }
        return "Signed in"
    }

    // MARK: - Headline (Serif font per Image 2)

    private var headlineSection: some View {
        VStack(alignment: .center, spacing: 6) {
            if let userName {
                Text("\(userName),")
                    .font(.system(size: 26, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            Text(userName == nil ? "Reach your goal without the bloat." : "reach your goal without the bloat.")
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 28)
        .padding(.top, 4)
    }

    // MARK: - Comparison Table (Free vs Premium)

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            // Header Tabs
            HStack(spacing: 0) {
                Spacer()

                Text("FREE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 80, height: 32)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 0)
                            .fill(Theme.Colors.surfaceRaised)
                    )

                Text("PREMIUM")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(Theme.Colors.onVolt)
                    .frame(width: 96, height: 32)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 10)
                            .fill(Theme.Colors.volt)
                    )
            }
            .padding(.trailing, 20)

            // Table Body
            VStack(spacing: 0) {
                ForEach(features.indices, id: \.self) { idx in
                    let item = features[idx]
                    HStack(spacing: 0) {
                        Text(item.name)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(.leading, 18)

                        Spacer()

                        // Free Column
                        ZStack {
                            if item.isFree {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color(hex: 0x2A7E4F))
                            }
                        }
                        .frame(width: 80)

                        // Premium Column
                        ZStack {
                            if item.isPremium {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color(hex: 0x2A7E4F))
                            }
                        }
                        .frame(width: 96)
                        .background(Color(hex: 0x4E7D3F).opacity(0.08))
                    }
                    .frame(height: 48)

                    if idx < features.count - 1 {
                        Divider()
                            .background(Theme.Colors.parchmentBorder.opacity(0.8))
                    }
                }
            }
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.Colors.parchmentBorder.opacity(0.85), lineWidth: 1)
            )
            .padding(.horizontal, 20)

            // Page Indicator Dots
            HStack(spacing: 6) {
                Circle().fill(Theme.Colors.textTertiary).frame(width: 6, height: 6)
                Circle().fill(Theme.Colors.parchmentBorder).frame(width: 6, height: 6)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Promo ribbon

    private func promoBanner(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.onVolt)
            Spacer()
        }
        .padding(.vertical, 12)
        .background(Theme.Colors.volt)
    }

    // MARK: - Plans (real App Store products)

    /// Monthly, yearly (center, most popular), lifetime — whatever the offering has.
    private var orderedPackages: [Package] {
        let rank: [PackageType: Int] = [.monthly: 0, .annual: 1, .lifetime: 2]
        return purchases.packages.sorted { (rank[$0.packageType] ?? 9) < (rank[$1.packageType] ?? 9) }
    }

    private var annualPackage: Package? { purchases.packages.first { $0.packageType == .annual } }

    private var selectedPackage: Package? {
        orderedPackages.first { $0.identifier == selectedID } ?? annualPackage ?? orderedPackages.first
    }

    /// Free-trial length in days, only if this Apple ID can still get it.
    private func trialDays(_ pkg: Package?) -> Int? {
        guard let product = pkg?.storeProduct, let intro = product.introductoryDiscount,
              intro.paymentMode == .freeTrial,
              purchases.trialEligible[product.productIdentifier] ?? true else { return nil }
        let p = intro.subscriptionPeriod
        switch p.unit {
        case .day: return p.value
        case .week: return p.value * 7
        case .month: return p.value * 30
        case .year: return p.value * 365
        @unknown default: return nil
        }
    }

    @ViewBuilder private var subscriptionTiersSection: some View {
        if orderedPackages.isEmpty {
            VStack(spacing: 10) {
                if purchases.isLoadingOfferings {
                    ProgressView().tint(Theme.Colors.volt)
                    Text("Loading plans...")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                } else {
                    Text("Couldn't load plans. Check your connection and try again.")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Try again") { Task { await purchases.loadOfferings() } }
                        .font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.volt)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            HStack(spacing: 10) {
                ForEach(orderedPackages, id: \.identifier) { pkg in
                    tierCard(pkg)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func tierCard(_ pkg: Package) -> some View {
        let product = pkg.storeProduct
        let isMostPopular = pkg.packageType == .annual
        let isSelected = pkg.identifier == selectedPackage?.identifier
        let (durationNumber, durationUnit): (String, String) = {
            switch pkg.packageType {
            case .monthly: return ("1", "month")
            case .annual: return ("12", "months")
            case .lifetime: return ("\u{221E}", "lifetime")
            default: return ("", product.localizedTitle)
            }
        }()
        let monthlyBreakdown: String = {
            if pkg.packageType == .lifetime { return "Pay once" }
            if let days = trialDays(pkg) { return "\(days) days free" }
            return product.localizedPricePerMonth.map { "\($0) / month" } ?? ""
        }()
        let billingNote: String = {
            switch pkg.packageType {
            case .monthly: return "Billed monthly"
            case .annual: return "Billed yearly"
            case .lifetime: return "No subscription"
            default: return ""
            }
        }()

        return Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedID = pkg.identifier
            }
        } label: {
            VStack(spacing: 0) {
                if isMostPopular {
                    Text("MOST POPULAR")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.Colors.onVolt)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(Theme.Colors.volt)
                } else {
                    Spacer().frame(height: 18)
                }

                VStack(spacing: 4) {
                    Text(durationNumber)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(isMostPopular ? Theme.Colors.onVolt : Theme.Colors.textPrimary)

                    Text(durationUnit)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(isMostPopular ? Theme.Colors.onVolt.opacity(0.85) : Theme.Colors.textSecondary)

                    Spacer().frame(height: 6)

                    Text(product.localizedPriceString)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(isMostPopular ? Theme.Colors.onVolt : Theme.Colors.textPrimary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    Divider()
                        .background(isMostPopular ? Color.white.opacity(0.3) : Theme.Colors.parchmentBorder)
                        .padding(.vertical, 6)

                    Text(monthlyBreakdown)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(isMostPopular ? Theme.Colors.onVolt : Theme.Colors.textPrimary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    Text(billingNote)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(isMostPopular ? Theme.Colors.onVolt.opacity(0.75) : Theme.Colors.textTertiary)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
            .background(isMostPopular ? Theme.Colors.volt : Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? (isMostPopular ? Color.white : Theme.Colors.volt) : Theme.Colors.parchmentBorder.opacity(0.85),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .shadow(color: isSelected ? Theme.Colors.volt.opacity(0.2) : Color.black.opacity(0.04), radius: 8, y: 3)
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(durationNumber) \(durationUnit), \(product.localizedPriceString)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Price, period and how renewal works, for the selected plan. Apple
    /// requires this to be clear next to the purchase button.
    private var finePrint: String {
        guard let pkg = selectedPackage else { return " " }
        let price = pkg.storeProduct.localizedPriceString
        switch pkg.packageType {
        case .annual:
            if let days = trialDays(pkg) {
                return "Free for \(days) days, then \(price) a year. Renews automatically. Cancel in Settings at least 24 hours before the trial ends and you won't be charged."
            }
            return "\(price) a year, renews automatically until you cancel in Settings."
        case .monthly:
            return "\(price) a month, renews automatically until you cancel in Settings."
        case .lifetime:
            return "One payment of \(price). No subscription."
        default:
            return "\(price)"
        }
    }

    private var ctaTitle: String {
        guard let pkg = selectedPackage else { return "CONTINUE" }
        if pkg.packageType == .annual, let days = trialDays(pkg) { return "START \(days)-DAY FREE TRIAL" }
        return "CONTINUE"
    }

    // MARK: - Trust Note

    private var trustNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.safe)

            Text(finePrint)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Fixed Bottom Checkout Bar

    private var bottomCheckoutBar: some View {
        VStack(spacing: 8) {
            // Renewal terms right above the button, always visible.
            trustNote

            // Large Green CONTINUE CTA
            Button {
                executePurchase()
            } label: {
                HStack {
                    if busy {
                        ProgressView().tint(Theme.Colors.onVolt)
                    } else {
                        Text(ctaTitle)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.Colors.onVolt)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.Colors.volt)
                        .shadow(color: Theme.Colors.volt.opacity(0.35), radius: 10, y: 4)
                )
            }
            .disabled(busy || selectedPackage == nil)
            .buttonStyle(.plain)

            // Links: Restore Purchase & Redeem Code
            HStack(spacing: 24) {
                Button {
                    Haptics.tap()
                    Task {
                        busy = true
                        await purchases.restore()
                        busy = false
                    }
                } label: {
                    Text("RESTORE PURCHASE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Button {
                    Haptics.tap()
                    // Redeem code action (opens App Store code redemption if available)
                    if let url = URL(string: "https://apps.apple.com/redeem") {
                        openURL(url)
                    }
                } label: {
                    Text("REDEEM CODE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(.top, 2)

            // Privacy & Terms
            HStack(spacing: 12) {
                Button("Terms of Use") { openURL(termsURL) }
                Text("·")
                Button("Privacy Policy") { openURL(privacyURL) }
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.Colors.textTertiary)
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            Theme.Colors.background
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: -4)
        )
    }

    private func executePurchase() {
        guard !busy, let pkg = selectedPackage else { return }
        Haptics.success()
        Task {
            busy = true
            await purchases.purchase(pkg)
            busy = false
            if purchases.isPremium && source != "gate" { dismiss() }
        }
    }
}
