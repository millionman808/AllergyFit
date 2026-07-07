import Foundation
import Supabase

/// Tracks auth state for the app.
@MainActor
final class SessionStore: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = true
    /// Demo mode: browse the full app with mock data, no account needed.
    @Published var isDemo = false
    @Published var demoOnboarded = false

    var isSignedIn: Bool { session != nil || isDemo }

    init() {
        // Debug/screenshot deep-links: launch with e.g. `-demo 1 -onboarded 1 -initialTab 2`
        if UserDefaults.standard.bool(forKey: "demo") {
            isDemo = true
            demoOnboarded = UserDefaults.standard.bool(forKey: "onboarded")
            isLoading = false
        }
        Task { await listen() }
    }

    private func listen() async {
        for await (event, session) in Backend.client.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                self.session = session
            case .signedOut, .userDeleted:
                self.session = nil
            default:
                break
            }
            isLoading = false
        }
    }

    func signOut() async {
        if isDemo {
            isDemo = false
            demoOnboarded = false
            return
        }
        try? await Backend.client.auth.signOut()
    }
}
