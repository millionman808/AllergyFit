import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: SessionStore

    @State private var navPath: [String] = {
        UserDefaults.standard.bool(forKey: "showLabScan") ? ["labscan"] : []
    }()

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
            .navigationDestination(for: String.self) { screen in
                if screen == "labscan" { LabScanView() }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            Text("E")
                .font(Theme.Fonts.stat(28))
                .foregroundStyle(Theme.Colors.onVolt)
                .frame(width: 64, height: 64)
                .background(Theme.Colors.volt, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(session.session?.user.email ?? "\(MockData.userName) (demo)")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Building muscle · 4 training days/week")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
        }
        .card()
    }

    private var allergenCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your triggers")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Button {
                } label: {
                    Text("Edit")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.volt)
                }
            }
            HStack(spacing: 8) {
                ForEach(MockData.allergens, id: \.self) { a in
                    Label(a, systemImage: "xmark.shield.fill")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.danger)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.danger.opacity(0.12), in: Capsule())
                }
            }
        }
        .card()
    }

    private var goalsCard: some View {
        HStack(spacing: Theme.Metrics.spacing) {
            goalStat("2,840", "kcal target")
            goalStat("180g", "protein")
            goalStat("175", "lb")
        }
    }

    private func goalStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.Fonts.stat(20))
                .foregroundStyle(Theme.Colors.volt)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    @AppStorage("appearance") private var appearance = "dark"

    private var settingsRows: some View {
        VStack(spacing: 2) {
            NavigationLink(value: "labscan") {
                settingsRow("Scan blood test results", "doc.text.viewfinder")
            }
            appearanceRow
            settingsRow("Goals & targets", "target")
            settingsRow("Dietary preferences", "leaf.fill")
            settingsRow("Notifications", "bell.fill")
            settingsRow("Apple Health", "heart.fill")
            settingsRow("Export for your allergist", "square.and.arrow.up.fill")
            settingsRow("Manage subscription", "crown.fill")
        }
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
    }

    private var appearanceRow: some View {
        HStack(spacing: 12) {
            Image(systemName: appearance == "light" ? "sun.max.fill" : "moon.fill")
                .font(.body)
                .foregroundStyle(Theme.Colors.volt)
                .frame(width: 28)
            Text("Appearance")
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Picker("", selection: $appearance) {
                Text("Dark").tag("dark")
                Text("Light").tag("light")
                Text("Auto").tag("system")
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
        }
        .padding(.horizontal, Theme.Metrics.cardPadding)
        .padding(.vertical, 9)
    }

    private func settingsRow(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.Colors.volt)
                .frame(width: 28)
            Text(title)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
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
}
