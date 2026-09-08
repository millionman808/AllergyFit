import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        Group {
            if session.isLoading {
                splash
            } else if session.session != nil && session.backendError && session.profileOnboarded == nil {
                OfflineView(retry: { await session.retry() })
            } else if session.isDemo && !session.demoOnboarded {
                OnboardingView()
            } else if session.session != nil && session.profileOnboarded == nil {
                splash // profile state loading
            } else if session.session != nil && session.profileOnboarded == false {
                OnboardingView()
            } else if session.isSignedIn {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.isSignedIn)
    }

    private var splash: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            Text("AllergyFit")
                .font(Theme.Fonts.stat(40))
                .foregroundStyle(Theme.Colors.volt)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var session: SessionStore
    @State private var selection = UserDefaults.standard.integer(forKey: "initialTab")
    @AppStorage("seenVoltIntro") private var seenVoltIntro = false
    @State private var showVoltIntro = false
    // One shared plan powers Today, Plan, recipe discovery, and meal completion.
    @StateObject private var planStore = PlanStore()

    var body: some View {
        content
            .environmentObject(planStore)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(selection: $selection)
            }
            .onAppear { planStore.configure(session: session) }
            .task {
                if !seenVoltIntro {
                    // Small beat so the app is visible behind the sheet.
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    showVoltIntro = true
                }
            }
            .sheet(isPresented: $showVoltIntro, onDismiss: { seenVoltIntro = true }) {
                VoltIntroSheet()
            }
    }

    @ViewBuilder private var content: some View {
        switch selection {
        case 1: PlanTab()
        case 2: LogView()
        case 3: InsightsTab()
        case 4: ProfileView()
        default: DashboardView(
            onOpenPlan: { selection = 1 },
            onCheckFood: { selection = 2 }
        )
        }
    }
}

/// The weekly planning workspace. Recipe discovery lives inside this flow so
/// planning, choosing, shopping, and cooking read as one job.
struct PlanTab: View {
    @State private var showRecipes = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                PlanView(onBrowseRecipes: { showRecipes = true })
            }
            .navigationTitle("Plan")
            .navigationDestination(isPresented: $showRecipes) {
                ZStack {
                    Theme.Colors.background.ignoresSafeArea()
                    RecipesView()
                }
                .navigationTitle("Find meals")
            }
        }
    }
}

/// Reaction learning is a primary product surface, not a profile setting.
struct InsightsTab: View {
    var body: some View {
        NavigationStack {
            InsightsView()
        }
    }
}

/// Custom bottom bar centered on the repeated product action: check or log food.
struct CustomTabBar: View {
    @Binding var selection: Int

    private struct Tab { let index: Int; let icon: String; let label: String }
    private let left: [Tab] = [
        Tab(index: 0, icon: "sun.max.fill", label: "Today"),
        Tab(index: 1, icon: "calendar", label: "Plan"),
    ]
    private let right: [Tab] = [
        Tab(index: 3, icon: "waveform.path.ecg", label: "Insights"),
        Tab(index: 4, icon: "person.fill", label: "Profile"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(left, id: \.index) { tabButton($0) }
            centerButton
            ForEach(right, id: \.index) { tabButton($0) }
        }
        .padding(.top, 8)
        .padding(.horizontal, 6)
        .background {
            Theme.Colors.surface
                .shadow(color: .black.opacity(0.06), radius: 8, y: -2)
                .ignoresSafeArea()
        }
    }

    private func tabButton(_ tab: Tab) -> some View {
        Button {
            Haptics.tap()
            selection = tab.index
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon).font(.system(size: 20))
                Text(tab.label).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selection == tab.index ? Theme.Colors.volt : Theme.Colors.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var centerButton: some View {
        Button {
            Haptics.tap()
            selection = 2
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.volt)
                        .frame(width: 58, height: 58)
                        .shadow(color: Theme.Colors.volt.opacity(0.4), radius: 10, y: 4)
                    Image(systemName: "viewfinder")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(Theme.Colors.onVolt)
                }
                Text("Check")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(selection == 2 ? Theme.Colors.volt : Theme.Colors.textSecondary)
            }
            .offset(y: -13)
        }
        .buttonStyle(.plain)
        .frame(width: 72)
        .accessibilityLabel("Check or log food")
    }
}
