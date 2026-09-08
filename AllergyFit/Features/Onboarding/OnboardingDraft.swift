import Foundation
import Supabase

/// Answers collected BEFORE the user has an account.
///
/// The pre-auth funnel asks for triggers, goal and body stats so people see
/// their real numbers before being asked to sign up. We hold those answers
/// locally, then apply them to the profile the moment an account exists — so
/// nobody is asked the same questions twice.
struct OnboardingDraft: Codable, Equatable {
    var allergenNames: Set<String> = []
    /// Triggers the user typed themselves — anything not in the standard list
    /// (e.g. "mango", "sulphites in wine"). Stored as user_allergens.custom_name.
    var customAllergens: [String] = []
    var severityByName: [String: String] = [:]     // display name → severity rawValue
    var goal: String = "Build muscle"              // Build muscle | Maintain | Cut
    var trainingDays: Int = 4
    var weightLb: Int = 175
    var heightFeet: Int = 5
    var heightInches: Int = 10
    var age: Int = 25

    private static let key = "onboardingDraft"

    static var stored: OnboardingDraft? {
        guard let d = UserDefaults.standard.data(forKey: key),
              let v = try? JSONDecoder().decode(OnboardingDraft.self, from: d) else { return nil }
        return v
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(d, forKey: Self.key)
        }
    }
    static func clear() { UserDefaults.standard.removeObject(forKey: Self.key) }

    // MARK: Derived targets (Mifflin-St Jeor, sex-neutral midpoint)

    var targets: (calories: Int, protein: Int, carbs: Int, fat: Int) {
        let kg = Double(weightLb) * 0.4536
        let cm = (Double(heightFeet) * 12 + Double(heightInches)) * 2.54
        let bmr = 10 * kg + 6.25 * cm - 5 * Double(age) - 78
        let activity: Double = trainingDays <= 1 ? 1.375 : trainingDays <= 3 ? 1.5
                             : trainingDays <= 5 ? 1.65 : 1.75
        var calories = bmr * activity
        switch goal {
        case "Cut": calories -= 400
        case "Build muscle": calories += 300
        default: break
        }
        let protein = Int((kg * 1.9).rounded())
        let fat = Int((kg * 0.9).rounded())
        let carbs = Int(((calories - Double(protein * 4) - Double(fat * 9)) / 4).rounded())
        return (Int(calories.rounded()), protein, max(carbs, 0), fat)
    }

    /// Write these answers onto the freshly created account.
    func apply(to userId: UUID) async throws {
        let goalValue = goal == "Cut" ? "cut" : goal == "Build muscle" ? "build" : "maintain"
        let t = targets
        struct ProfileUpdate: Codable {
            let fitness_goal: String
            let birth_year: Int
            let height_cm: Double
            let weight_kg: Double
            let training_days_per_week: Int
            let target_calories: Int
            let target_protein_g: Int
            let target_carbs_g: Int
            let target_fat_g: Int
            let onboarding_completed: Bool
        }
        let update = ProfileUpdate(
            fitness_goal: goalValue,
            birth_year: Calendar.current.component(.year, from: Date()) - age,
            height_cm: (Double(heightFeet) * 12 + Double(heightInches)) * 2.54,
            weight_kg: Double(weightLb) * 0.4536,
            training_days_per_week: trainingDays,
            target_calories: t.calories,
            target_protein_g: t.protein,
            target_carbs_g: t.carbs,
            target_fat_g: t.fat,
            onboarding_completed: true)
        try await Backend.client.from("profiles").update(update)
            .eq("id", value: userId).execute()

        struct ARow: Codable { let id: Int; let slug: String }
        let known: [ARow] = try await Backend.client
            .from("allergens").select("id, slug").execute().value
        let idBySlug = Dictionary(uniqueKeysWithValues: known.map { ($0.slug, $0.id) })

        struct UAInsert: Codable {
            let user_id: UUID
            let allergen_id: Int
            let severity: String
        }
        let rows: [UAInsert] = allergenNames.compactMap { name in
            guard let slug = AllergenCatalog.slugByName[name],
                  let id = idBySlug[slug] else { return nil }
            return UAInsert(user_id: userId, allergen_id: id,
                            severity: severityByName[name] ?? "moderate")
        }
        if !rows.isEmpty {
            try await Backend.client.from("user_allergens")
                .upsert(rows, onConflict: "user_id,allergen_id", ignoreDuplicates: true)
                .execute()
        }

        // Custom triggers have no allergen_id — they ride on custom_name.
        struct CustomInsert: Codable {
            let user_id: UUID
            let custom_name: String
            let severity: String
        }
        let customRows = customAllergens
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { CustomInsert(user_id: userId, custom_name: $0,
                                severity: severityByName[$0] ?? "moderate") }
        if !customRows.isEmpty {
            try await Backend.client.from("user_allergens").insert(customRows).execute()
        }
    }
}
