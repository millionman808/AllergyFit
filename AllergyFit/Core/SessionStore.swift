import Foundation
import Supabase

/// Tracks auth state + the signed-in user's profile essentials
/// (onboarding status and allergen profile used across the app).
@MainActor
final class SessionStore: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = true
    /// Demo mode: browse the full app with mock data, no account needed.
    @Published var isDemo = false
    @Published var demoOnboarded = false
    /// nil while loading for a signed-in user; demo users don't use this.
    @Published var profileOnboarded: Bool?
    /// Allergen slugs powering recipes, meal analysis, and swaps.
    /// Demo default matches the mock profile; replaced by DB values on sign-in.
    @Published var allergenSlugs: [String] = ["peanut", "dairy", "sesame"]

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
                if let user = session?.user, event == .initialSession || event == .signedIn {
                    Task { await loadProfileState(userId: user.id) }
                    Task { await PurchasesManager.shared.identify(userId: user.id.uuidString) }
                }
            case .signedOut, .userDeleted:
                self.session = nil
                self.profileOnboarded = nil
            default:
                break
            }
            isLoading = false
        }
    }

    /// Loads onboarding flag + allergen slugs for the signed-in user.
    func loadProfileState(userId: UUID) async {
        struct ProfileFlags: Codable {
            let onboardingCompleted: Bool?
            enum CodingKeys: String, CodingKey { case onboardingCompleted = "onboarding_completed" }
        }
        do {
            let flags: ProfileFlags = try await Backend.client
                .from("profiles")
                .select("onboarding_completed")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            profileOnboarded = flags.onboardingCompleted ?? false
        } catch {
            print("profile flags load failed: \(error)")
            profileOnboarded = false
        }
        await reloadAllergens(userId: userId)
    }

    func reloadAllergens(userId: UUID) async {
        struct UARow: Codable {
            let allergenId: Int?
            let customName: String?
            enum CodingKeys: String, CodingKey {
                case allergenId = "allergen_id"
                case customName = "custom_name"
            }
        }
        struct ARow: Codable { let id: Int; let slug: String }
        do {
            let mine: [UARow] = try await Backend.client
                .from("user_allergens").select("allergen_id, custom_name")
                .eq("user_id", value: userId)
                .execute().value
            let known: [ARow] = try await Backend.client
                .from("allergens").select("id, slug")
                .execute().value
            let idToSlug = Dictionary(uniqueKeysWithValues: known.map { ($0.id, $0.slug) })
            let slugs = mine.compactMap { $0.allergenId.flatMap { idToSlug[$0] } }
            if !slugs.isEmpty { allergenSlugs = slugs }
        } catch {
            print("allergen load failed: \(error)")
        }
    }

    func signOut() async {
        if isDemo {
            isDemo = false
            demoOnboarded = false
            allergenSlugs = ["peanut", "dairy", "sesame"]
            return
        }
        await PurchasesManager.shared.signOut()
        try? await Backend.client.auth.signOut()
    }
}
