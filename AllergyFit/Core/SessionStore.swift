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
    /// True when the backend couldn't be reached and we have no cached state to
    /// fall back on — drives the offline screen instead of a blank/stuck view.
    @Published var backendError = false

    private let cachedOnboardedKey = "cachedOnboarded"
    fileprivate static let cachedAllergenSlugsKey = "cachedAllergenSlugs"

    /// Last known trigger slugs, readable outside the app's UI (e.g. the Siri
    /// intent, which runs without a live SessionStore).
    nonisolated static var cachedAllergenSlugs: [String] {
        UserDefaults.standard.stringArray(forKey: cachedAllergenSlugsKey) ?? []
    }
    /// Allergen slugs powering recipes, meal analysis, and swaps.
    /// Demo default matches the mock profile; replaced by DB values on sign-in.
    @Published var allergenSlugs: [String] = ["peanut", "dairy", "sesame"]
    /// Sensitivity level per allergen slug (drives how strongly items are flagged).
    @Published var severityBySlug: [String: Sensitivity] = [
        "peanut": .anaphylaxis, "dairy": .moderate, "sesame": .severe,
    ]

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
            let onboarded = flags.onboardingCompleted ?? false
            profileOnboarded = onboarded
            backendError = false
            UserDefaults.standard.set(onboarded, forKey: cachedOnboardedKey)
        } catch {
            print("profile flags load failed: \(error)")
            // Don't strand a signed-in user in onboarding on a transient outage.
            // Use the last known state if we have it; otherwise surface offline.
            if UserDefaults.standard.object(forKey: cachedOnboardedKey) != nil {
                profileOnboarded = UserDefaults.standard.bool(forKey: cachedOnboardedKey)
                backendError = true
            } else {
                profileOnboarded = nil
                backendError = true
                return   // no cached state → OfflineView; skip allergen load
            }
        }
        await reloadAllergens(userId: userId)
    }

    /// Retry loading backend state (from the offline screen).
    func retry() async {
        guard let userId = session?.user.id else {
            backendError = false
            return
        }
        await loadProfileState(userId: userId)
    }

    func reloadAllergens(userId: UUID) async {
        struct UARow: Codable {
            let allergenId: Int?
            let customName: String?
            let severity: String?
            enum CodingKeys: String, CodingKey {
                case allergenId = "allergen_id"
                case customName = "custom_name"
                case severity
            }
        }
        struct ARow: Codable { let id: Int; let slug: String }
        do {
            let mine: [UARow] = try await Backend.client
                .from("user_allergens").select("allergen_id, custom_name, severity")
                .eq("user_id", value: userId)
                .execute().value
            let known: [ARow] = try await Backend.client
                .from("allergens").select("id, slug")
                .execute().value
            let idToSlug = Dictionary(uniqueKeysWithValues: known.map { ($0.id, $0.slug) })
            let slugs = mine.compactMap { $0.allergenId.flatMap { idToSlug[$0] } }
            if !slugs.isEmpty {
                allergenSlugs = slugs
                // Cached so the Siri intent can check triggers without a session load.
                UserDefaults.standard.set(slugs, forKey: Self.cachedAllergenSlugsKey)
            }
            var sevMap: [String: Sensitivity] = [:]
            for row in mine {
                if let id = row.allergenId, let slug = idToSlug[id] {
                    sevMap[slug] = Sensitivity.from(row.severity)
                }
            }
            if !sevMap.isEmpty { severityBySlug = sevMap }
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
