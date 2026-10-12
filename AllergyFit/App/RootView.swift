import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var purchases: PurchasesManager
    @AppStorage("seenPreAuthOnboarding") private var seenPreAuth = false
    #if DEBUG
    private static let forcePaywall = UserDefaults.standard.bool(forKey: "forcePaywall")
    #else
    private static let forcePaywall = false
    #endif
    @State private var startInSignUpMode = true

    var body: some View {
        Group {
            if Self.forcePaywall {
                // Debug only: `-forcePaywall YES` previews the gate without signing in.
                PaywallView(source: "debug")
            } else if session.isDemo && session.demoOnboarded {
                MainTabView()
            } else if !seenPreAuth {
                // High-converting funnel: answers -> calculation -> account creation -> single-screen paywall
                PreAuthOnboardingView(
                    onFinish: {
                        seenPreAuth = true
                    },
                    onSignIn: {
                        startInSignUpMode = false
                        seenPreAuth = true
                    }
                )
            } else if session.isLoading {
                // Returning users: wait for the saved session instead of
                // flashing the sign-in screen. New users never see this (the
                // onboarding branch above comes first).
                splash
            } else if session.session != nil && session.backendError && session.profileOnboarded == nil {
                OfflineView(retry: { await session.retry() })
            } else if session.isDemo && !session.demoOnboarded {
                PreAuthOnboardingView(onFinish: {
                    seenPreAuth = true
                })
            } else if session.session != nil && session.profileOnboarded == nil {
                splash // profile state loading
            } else if session.session != nil && session.profileOnboarded == false {
                PreAuthOnboardingView(onFinish: {
                    seenPreAuth = true
                })
            } else if session.isSignedIn {
                membershipGate
            } else {
                // Backing out returns to onboarding rather than trapping people on a login wall.
                AuthView(onBack: { seenPreAuth = false }, startInSignUpMode: startInSignUpMode)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.isSignedIn)
        .animation(.easeInOut(duration: 0.25), value: purchases.hasPremiumAccess)
    }

    /// Hard paywall: the app opens only with an active trial, subscription or
    /// lifetime unlock. Waits for RevenueCat's answer first so a subscriber
    /// never sees the paywall flash on launch.
    @ViewBuilder private var membershipGate: some View {
        if session.isDemo || purchases.hasPremiumAccess {
            MainTabView()
        } else if !purchases.customerInfoLoaded {
            splash
        } else {
            PaywallView(source: "gate")
        }
    }

    private var splash: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            VStack(spacing: 10) {
                Image("pip_happy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                Text("SafeFuel")
                    .font(Theme.Fonts.stat(36))
                    .foregroundStyle(Theme.Colors.volt)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var session: SessionStore
    @State private var selection = UserDefaults.standard.integer(forKey: "initialTab")
    @AppStorage("seenVoltIntro") private var seenVoltIntro = false
    @State private var showVoltIntro = false
    @State private var showQuickActionSheet = UserDefaults.standard.bool(forKey: "quickAction")
    // One shared plan powers Today, Plan, recipe discovery, and meal completion.
    @StateObject private var planStore = PlanStore()

    var body: some View {
        content
            .environmentObject(planStore)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(selection: $selection, onQuickAction: {
                    showQuickActionSheet = true
                })
            }
            .sheet(isPresented: $showQuickActionSheet) {
                AlmaQuickActionSheet()
            }
            // Goal confetti, above every tab.
            .overlay { PipConfettiLayer() }
            .onAppear { planStore.configure(session: session) }
            .task {
                if !seenVoltIntro {
                    // Small beat so the app is visible behind the sheet.
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    showVoltIntro = true
                }
            }
            .sheet(isPresented: $showVoltIntro, onDismiss: {
                seenVoltIntro = true
                // Safety net for anyone who skipped the onboarding prompt:
                // ask once the intro closes, never on top of it.
                Task { await AdAttribution.requestTrackingIfNeeded() }
            }) {
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
            onCheckFood: { showQuickActionSheet = true }
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

/// Custom bottom bar with Alma-inspired floating frosted aesthetic and central elevated '+' trigger.
struct CustomTabBar: View {
    @Binding var selection: Int
    var onQuickAction: () -> Void

    private struct Tab { let index: Int; let icon: String; let label: String }
    private let left: [Tab] = [
        Tab(index: 0, icon: "house.fill", label: "Today"),
        Tab(index: 1, icon: "calendar", label: "Plan"),
    ]
    private let right: [Tab] = [
        Tab(index: 3, icon: "sparkles", label: "Insights"),
        Tab(index: 4, icon: "person.fill", label: "Profile"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(left, id: \.index) { tabButton($0) }
            centerButton
            ForEach(right, id: \.index) { tabButton($0) }
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Theme.Colors.surface.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Theme.Colors.parchmentBorder.opacity(0.85), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 16, y: 6)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    private func tabButton(_ tab: Tab) -> some View {
        Button {
            Haptics.tap()
            selection = tab.index
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 19, weight: selection == tab.index ? .semibold : .regular))
                Text(tab.label)
                    .font(.system(size: 10, weight: selection == tab.index ? .bold : .medium, design: .rounded))
            }
            .foregroundStyle(selection == tab.index ? Theme.Colors.volt : Theme.Colors.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var centerButton: some View {
        Button {
            Haptics.tap()
            onQuickAction()
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.Colors.volt)
                    .frame(width: 52, height: 52)
                    .shadow(color: Theme.Colors.volt.opacity(0.35), radius: 10, y: 4)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.Colors.onVolt)
            }
            .offset(y: -14)
        }
        .buttonStyle(.plain)
        .frame(width: 66)
        .accessibilityLabel("Track food or ask Concierge")
    }
}
