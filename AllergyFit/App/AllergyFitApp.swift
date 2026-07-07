import SwiftUI

@main
struct AllergyFitApp: App {
    @StateObject private var session = SessionStore()
    @AppStorage("appearance") private var appearance = "dark"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(colorScheme)
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
