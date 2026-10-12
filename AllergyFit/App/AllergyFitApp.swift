import SwiftUI
import GoogleSignIn

@main
struct AllergyFitApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var purchases = PurchasesManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        PurchasesManager.shared.start()
        // Each network is skipped until its IDs are set in AdConfig.
        AdAttribution.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(purchases)
                // The cozy palette is light-only; system sheets and alerts match it.
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onChange(of: scenePhase) { phase in
                    // AppsFlyer and Meta count sessions per foreground.
                    if phase == .active { AdAttribution.start() }
                }
        }
    }
}
