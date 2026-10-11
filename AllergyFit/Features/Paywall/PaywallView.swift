import SwiftUI
import RevenueCat

/// The SafeFuel paywall, shown as a gate: until a trial or purchase is active
/// the app stays here, including on every relaunch.
///
/// Every price, period and trial comes from the App Store through RevenueCat —
/// nothing is typed in — so each storefront shows its own currency, and nobody
/// is promised a free trial their Apple ID has already used.
///
/// Because this screen can be all a non-subscriber ever sees, it carries its
/// own account menu: Apple requires in-app account deletion, and a gate that
/// hides Profile would otherwise make that impossible.
struct PaywallView: View {
    var source: String = "gate"

    @EnvironmentObject var purchases: PurchasesManager
    @EnvironmentObject var session: SessionStore
    @Environment(\.openURL) private var openURL

    @State private var selectedID: String?
    @State private var busy = false
    @State private var showAccountMenu = false
    @State private var confirmDelete = false
    @State private var confirmAnonSignOut = false
    @State private var showSaveAccount = false
    @State private var accountError: String?

    private let privacyURL = URL(string: "https://safefuel.schafersites.com/privacy")!
    private let termsURL = URL(string: "https://safefuel.schafersites.com/terms")!

    var body: some View {
        ZStack {
            Club.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    perks
                    plans
                    if let err = purchases.purchaseError ?? accountError {
                        Text(err)
                            .font(Club.Fonts.caption)
                            .foregroundStyle(Club.Colors.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .safeAreaInset(edge: .bottom, spacing: 0) { checkout }
        .onAppear { AdAttribution.logPaywallView(source: source) }
        .task {
            if purchases.packages.isEmpty { await purchases.loadOfferings() }
            if selectedID == nil { selectedID = ordered.first?.identifier }
        }
        .onChange(of: purchases.packages.count) { _ in
            if selectedID == nil { selectedID = ordered.first?.identifier }
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
            Text("This permanently removes your profile, triggers, meals and plans. An App Store subscription is managed by Apple and isn't cancelled by deleting your account.")
        }
        .sheet(isPresented: $showSaveAccount) { SaveAccountSheet() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { showAccountMenu = true } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Club.Colors.textSecondary)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Account")
            Spacer()
            Button("Restore") {
                Task {
                    busy = true
                    await purchases.restore()
                    busy = false
                }
            }
            .font(Club.Fonts.caption)
            .foregroundStyle(Club.Colors.textSecondary)
            .disabled(busy)
        }
        .padding(.horizontal, 14)
        .background(Club.Colors.background)
    }

    private var accountLine: String {
        if session.isAnonymous { return "You're using SafeFuel without an account." }
        if let email = session.session?.user.email { return "Signed in as \(email)" }
        return "Signed in"
    }

    // MARK: - Header and perks

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            ClubCrest(size: 52)
            Text("SafeFuel membership")
                .font(Club.Fonts.clubTag(11)).tracking(2.2)
                .textCase(.uppercase)
                .foregroundStyle(Club.Colors.antiqueBrass)
            HighlightHeadline(text: "Reach your goal without the bloat.", highlight: "without the bloat", size: 30)
        }
    }

    private var perks: some View {
        VStack(alignment: .leading, spacing: 14) {
            perk("camera.fill", "Snap any meal",
                 "Calories from the USDA database, checked against your triggers.")
            perk("fork.knife", "Meals planned for you",
                 "A week that fits your goal and your stomach, with the grocery list.")
            perk("waveform.path.ecg", "Find your triggers",
                 "See which foods keep turning up before you feel bad.")
            perk("heart.fill", "Targets that move with you",
                 "Calories adjust to your workouts from Apple Health.")
        }
        .padding(18)
        .background(Club.Colors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Club.Colors.parchmentBorder, lineWidth: 1))
    }

    private func perk(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Club.Colors.racingGreen)
                .frame(width: 30, height: 30)
                .background(Club.Colors.racingGreen.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Club.Fonts.headline).foregroundStyle(Club.Colors.textPrimary)
                Text(detail).font(Club.Fonts.caption).foregroundStyle(Club.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Plans

    /// Annual first (preselected), then monthly, then lifetime.
    private var ordered: [Package] {
        let rank: [PackageType: Int] = [.annual: 0, .monthly: 1, .lifetime: 2]
        return purchases.packages.sorted { (rank[$0.packageType] ?? 9) < (rank[$1.packageType] ?? 9) }
    }

    private var selected: Package? {
        ordered.first { $0.identifier == selectedID } ?? ordered.first
    }

    @ViewBuilder private var plans: some View {
        if ordered.isEmpty {
            VStack(spacing: 10) {
                if purchases.isLoadingOfferings {
                    ProgressView().tint(Club.Colors.racingGreen)
                    Text("Loading plans…").font(Club.Fonts.caption).foregroundStyle(Club.Colors.textSecondary)
                } else {
                    Text("Couldn't load plans. Check your connection and try again.")
                        .font(Club.Fonts.caption).foregroundStyle(Club.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Try again") { Task { await purchases.loadOfferings() } }
                        .font(Club.Fonts.headline).foregroundStyle(Club.Colors.racingGreen)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        } else {
            VStack(spacing: 10) {
                ForEach(ordered, id: \.identifier) { pkg in
                    Button {
                        Haptics.tap()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selectedID = pkg.identifier }
                    } label: { planRow(pkg) }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func planRow(_ pkg: Package) -> some View {
        let on = pkg.identifier == selected?.identifier
        let product = pkg.storeProduct
        return HStack(spacing: 14) {
            ZStack {
                Circle().strokeBorder(on ? Club.Colors.racingGreen : Club.Colors.parchmentBorder, lineWidth: 1.5)
                if on { Circle().fill(Club.Colors.racingGreen).padding(5) }
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(planName(pkg)).font(Club.Fonts.headline).foregroundStyle(Club.Colors.textPrimary)
                    if let badge = badge(pkg) {
                        Text(badge)
                            .font(Club.Fonts.clubTag(9)).tracking(1.2)
                            .foregroundStyle(Club.Colors.onVolt)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Club.Colors.antiqueBrass, in: Capsule())
                    }
                }
                if let sub = planSubtitle(pkg) {
                    Text(sub).font(Club.Fonts.caption).foregroundStyle(Club.Colors.textSecondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(product.localizedPriceString)
                    .font(Club.Fonts.headline).foregroundStyle(Club.Colors.textPrimary)
                Text(periodWord(pkg)).font(Club.Fonts.caption).foregroundStyle(Club.Colors.textTertiary)
            }
        }
        .padding(16)
        .background(Club.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(on ? Club.Colors.racingGreen : Club.Colors.parchmentBorder, lineWidth: on ? 1.5 : 1))
        .shadow(color: .black.opacity(on ? 0.08 : 0), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private func planName(_ pkg: Package) -> String {
        switch pkg.packageType {
        case .annual: return "Yearly"
        case .monthly: return "Monthly"
        case .lifetime: return "Lifetime"
        default: return pkg.storeProduct.localizedTitle
        }
    }

    private func periodWord(_ pkg: Package) -> String {
        switch pkg.packageType {
        case .annual: return "per year"
        case .monthly: return "per month"
        case .lifetime: return "one time"
        default: return ""
        }
    }

    private func planSubtitle(_ pkg: Package) -> String? {
        switch pkg.packageType {
        case .annual:
            if let days = trialDays(pkg) {
                return "\(days) days free, then \(pkg.storeProduct.localizedPricePerMonth ?? "") a month"
            }
            return pkg.storeProduct.localizedPricePerMonth.map { "\($0) a month, billed yearly" }
        case .monthly: return "Cancel any time"
        case .lifetime: return "Pay once, keep it for good"
        default: return nil
        }
    }

    private func badge(_ pkg: Package) -> String? {
        guard pkg.packageType == .annual else { return nil }
        if let days = trialDays(pkg) { return "\(days) DAYS FREE" }
        return "BEST VALUE"
    }

    /// Free-trial length in days — only if this Apple ID can still get it.
    private func trialDays(_ pkg: Package) -> Int? {
        let product = pkg.storeProduct
        guard let intro = product.introductoryDiscount, intro.paymentMode == .freeTrial,
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

    // MARK: - Checkout (pinned)

    private var checkout: some View {
        VStack(spacing: 8) {
            Button {
                guard let pkg = selected else { return }
                Task {
                    busy = true
                    await purchases.purchase(pkg)
                    busy = false
                    if purchases.isPremium { Haptics.success() }
                }
            } label: {
                Group {
                    if busy { ProgressView().tint(Club.Colors.onVolt) }
                    else { Text(ctaTitle).font(Club.Fonts.headline) }
                }
                .foregroundStyle(Club.Colors.onVolt)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(selected == nil ? Club.Colors.surfaceRaised : Club.Colors.volt,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(busy || selected == nil)
            .pressable()

            Text(finePrint)
                .font(.system(size: 11))
                .foregroundStyle(Club.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                Button("Terms of Use") { openURL(termsURL) }
                Text("·")
                Button("Privacy Policy") { openURL(privacyURL) }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Club.Colors.textTertiary)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(Club.Colors.background.shadow(.drop(color: .black.opacity(0.06), radius: 8, y: -2)))
    }

    private var ctaTitle: String {
        guard let pkg = selected else { return "Continue" }
        let price = pkg.storeProduct.localizedPriceString
        switch pkg.packageType {
        case .annual:
            if let days = trialDays(pkg) { return "Start \(days)-day free trial" }
            return "Subscribe for \(price) a year"
        case .monthly: return "Subscribe for \(price) a month"
        case .lifetime: return "Unlock for \(price)"
        default: return "Continue"
        }
    }

    /// Apple requires the price, the billing period and how renewal works to be
    /// clear right next to the button.
    private var finePrint: String {
        guard let pkg = selected else { return " " }
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
        default: return " "
        }
    }
}
