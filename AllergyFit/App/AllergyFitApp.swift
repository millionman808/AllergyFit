import SwiftUI
import GoogleSignIn

@main
struct AllergyFitApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var purchases = PurchasesManager.shared
    @AppStorage("appearance") private var appearance = "dark"

    init() {
        PurchasesManager.shared.start()
        // No-op unless a Meta/TikTok ID is configured in AdAttribution.
        AdAttribution.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(purchases)
                .preferredColorScheme(colorScheme)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    // Asked after the app is usable, not on a cold first launch
                    // where the prompt has no context and just gets denied.
                    await AdAttribution.requestTrackingIfNeeded()
                }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil // follow system
        }
    }
}
