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
    // Hoisted so the Plan and Recipes tabs (now separate) share one plan.
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
        case 1: LogView()
        case 2: PlanTab(selection: $selection)
        case 3: RecipesTab()
        case 4: ProfileView()
        default: DashboardView()
        }
    }
}

/// Meal planner tab — the app's primary surface. Owns its navigation stack so
/// the week, grocery list, and cook mode all push here.
struct PlanTab: View {
    @Binding var selection: Int
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                PlanView(onBrowseRecipes: { selection = 3 })   // jump to Recipes tab
            }
            .navigationTitle("Plan")
        }
    }
}

/// Recipe discovery tab — safe-only browse + generate.
struct RecipesTab: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                RecipesView()
            }
            .navigationTitle("Recipes")
        }
    }
}

/// Custom bottom bar with a raised center capture button (Snap Calorie–style).
/// Log is the app's primary action, so it's elevated instead of sitting flat
/// with the other tabs.
struct CustomTabBar: View {
    @Binding var selection: Int

    private struct Tab { let index: Int; let icon: String; let label: String }
    private let left: [Tab] = [
        Tab(index: 0, icon: "flame.fill", label: "Today"),
        Tab(index: 2, icon: "calendar", label: "Plan"),
    ]
    private let right: [Tab] = [
        Tab(index: 3, icon: "book.fill", label: "Recipes"),
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
            selection = 1
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.Colors.volt)
                    .frame(width: 58, height: 58)
                    .shadow(color: Theme.Colors.volt.opacity(0.4), radius: 10, y: 4)
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.Colors.onVolt)
            }
            .offset(y: -16)
        }
        .buttonStyle(.plain)
        .frame(width: 72)
        .accessibilityLabel("Log")
    }
}
