import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        Group {
            if session.isLoading {
                splash
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
    @State private var selection = UserDefaults.standard.integer(forKey: "initialTab")

    var body: some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(selection: $selection)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder private var content: some View {
        switch selection {
        case 1: LogView()
        case 2: KitchenView()
        case 3: InsightsView()
        case 4: ProfileView()
        default: DashboardView()
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
        Tab(index: 2, icon: "fork.knife", label: "Kitchen"),
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
