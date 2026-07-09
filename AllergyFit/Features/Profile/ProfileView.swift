import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var store = ProfileStore()
    @StateObject private var health = HealthManager()
    @AppStorage("appearance") private var appearance = "dark"

    @State private var navPath: [String] = {
        UserDefaults.standard.bool(forKey: "showLabScan") ? ["labscan"] : []
    }()
    @State private var showTriggers = false
    @State private var showGoals = false
    @State private var showDietary = false
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Metrics.spacing) {
                        headerCard
                        allergenCard
                        goalsCard
                        settingsRows
                        signOut
                    }
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Profile")
            .onAppear { store.configure(session: session) }
            .navigationDestination(for: String.self) { screen in
                switch screen {
                case "labscan": LabScanView()
                case "notifications": NotificationsView()
                case "subscription": SubscriptionView()
                default: EmptyView()
                }
            }
            .sheet(isPresented: $showTriggers) {
                EditTriggersView(currentSlugs: session.allergenSlugs)
            }
            .sheet(isPresented: $showGoals) { GoalsEditorView(store: store) }
            .sheet(isPresented: $showDietary) { DietaryPrefsView(store: store) }
            .sheet(item: $shareURL) { url in ShareSheet(items: [url]) }
        }
    }

    // MARK: Header

    private var headerCard: some View {
        HStack(spacing: 14) {
            Text(initials)
                .font(Theme.Fonts.stat(28))
                .foregroundStyle(Theme.Colors.onVolt)
                .frame(width: 64, height: 64)
                .background(Theme.Colors.volt, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("\(store.goalLabel) · \(store.trainingDays) training days/week")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
        }
        .card()
    }

    private var displayName: String {
        if session.isDemo { return "\(MockData.userName) (demo)" }
        if !store.displayName.isEmpty { return store.displayName }
        return store.email ?? "Your profile"
    }
    private var initials: String {
        String(displayName.prefix(1)).uppercased()
    }

    // MARK: Allergens

    private var allergenCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your triggers")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Button { showTriggers = true } label: {
                    Text("Edit").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.volt)
                }
            }
            if session.allergenSlugs.isEmpty {
                Text("No triggers set — tap Edit to add them.")
                    .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            } else {
                FlowTags(items: AllergenCatalog.names(for: session.allergenSlugs),
                         icon: "xmark.shield.fill", color: Theme.Colors.danger)
            }
        }
        .card()
    }

    // MARK: Goals summary

    private var goalsCard: some View {
        Button { showGoals = true } label: {
            HStack(spacing: Theme.Metrics.spacing) {
                goalStat("\(store.targetCalories.formatted())", "kcal target")
                goalStat("\(store.targetProtein)g", "protein")
                goalStat("\(store.weightLb)", "lb")
            }
        }
    }

    private func goalStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(Theme.Fonts.stat(20)).foregroundStyle(Theme.Colors.volt)
            Text(label).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    // MARK: Settings rows

    private var settingsRows: some View {
        VStack(spacing: 2) {
            NavigationLink(value: "labscan") { settingsRow("Scan blood test results", "doc.text.viewfinder") }
            appearanceRow
            Button { showGoals = true } label: { settingsRow("Goals & targets", "target") }
            Button { showDietary = true } label: { settingsRow("Dietary preferences", "leaf.fill") }
            NavigationLink(value: "notifications") { settingsRow("Notifications", "bell.fill") }
            healthRow
            Button { exportReport() } label: { settingsRow("Export for your allergist", "square.and.arrow.up.fill") }
            NavigationLink(value: "subscription") { settingsRow("Manage subscription", "crown.fill") }
        }
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
    }

    private var healthRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill").font(.body).foregroundStyle(Theme.Colors.volt).frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("Apple Health").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                if health.connected {
                    Text("Connected").font(.system(size: 11, design: .rounded)).foregroundStyle(Theme.Colors.safe)
                }
            }
            Spacer()
            if health.connected {
                Button("Disconnect") { health.disconnect() }
                    .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            } else {
                Button("Connect") { Task { await health.connect() } }
                    .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.volt)
            }
        }
        .padding(.horizontal, Theme.Metrics.cardPadding)
        .padding(.vertical, 13)
    }

    private var appearanceRow: some View {
        HStack(spacing: 12) {
            Image(systemName: appearance == "light" ? "sun.max.fill" : "moon.fill")
                .font(.body).foregroundStyle(Theme.Colors.volt).frame(width: 28)
            Text("Appearance").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Picker("", selection: $appearance) {
                Text("Dark").tag("dark"); Text("Light").tag("light"); Text("Auto").tag("system")
            }
            .pickerStyle(.segmented).frame(width: 170)
        }
        .padding(.horizontal, Theme.Metrics.cardPadding)
        .padding(.vertical, 9)
    }

    private func settingsRow(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.body).foregroundStyle(Theme.Colors.volt).frame(width: 28)
            Text(title).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.Colors.textTertiary)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, Theme.Metrics.cardPadding)
        .padding(.vertical, 13)
    }

    private var signOut: some View {
        Button {
            Task { await session.signOut() }
        } label: {
            Text(session.isDemo ? "Exit demo" : "Sign out")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.danger)
                .frame(maxWidth: .infinity)
                .card()
        }
    }

    private func exportReport() {
        shareURL = AllergistReport.makePDF(
            name: session.isDemo ? MockData.userName : (store.displayName.isEmpty ? (store.email ?? "AllergyFit user") : store.displayName),
            allergens: AllergenCatalog.names(for: session.allergenSlugs),
            goal: store.goalLabel,
            calories: store.targetCalories,
            protein: store.targetProtein
        )
    }
}

// MARK: - Share sheet + URL Identifiable

extension URL: Identifiable { public var id: String { absoluteString } }

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
