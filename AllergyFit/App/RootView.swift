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
        TabView(selection: $selection) {
            DashboardView()
                .tabItem { Label("Today", systemImage: "flame.fill") }
                .tag(0)
            LogView()
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }
                .tag(1)
            KitchenView()
                .tabItem { Label("Kitchen", systemImage: "fork.knife") }
                .tag(2)
            InsightsView()
                .tabItem { Label("Insights", systemImage: "waveform.path.ecg") }
                .tag(3)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(4)
        }
        .tint(Theme.Colors.volt)
    }
}
