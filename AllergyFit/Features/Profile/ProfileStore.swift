import Foundation
import Supabase

/// Loads and edits the signed-in user's profile. Demo mode uses in-memory values.
@MainActor
final class ProfileStore: ObservableObject {
    @Published var displayName = ""
    @Published var email: String?
    @Published var goal = "build"                 // cut | build | maintain
    @Published var age = 25
    @Published var heightCm = 178.0
    @Published var weightKg = 79.4
    @Published var trainingDays = 4
    @Published var targetCalories = 2840
    @Published var targetProtein = 180
    @Published var targetCarbs = 320
    @Published var targetFat = 84
    @Published var dietaryPreferences: [String] = []
    @Published var isLoading = false

    private var isDemo = true
    private var userId: UUID?
    private var configured = false

    var goalLabel: String {
        switch goal { case "cut": return "Cutting"; case "build": return "Building muscle"; default: return "Maintaining" }
    }
    var weightLb: Int { Int((weightKg / 0.4536).rounded()) }
    var heightFeet: Int { Int(heightCm / 2.54) / 12 }
    var heightInches: Int { Int((heightCm / 2.54).rounded()) % 12 }

    func configure(session: SessionStore) {
        guard !configured else { return }
        configured = true
        isDemo = session.isDemo
        userId = session.session?.user.id
        email = session.session?.user.email
        if isDemo {
            displayName = MockData.userName
            dietaryPreferences = []
        } else {
            Task { await load() }
        }
    }

    struct ProfileRow: Codable {
        var displayName: String?
        var fitnessGoal: String?
        var birthYear: Int?
        var heightCm: Double?
        var weightKg: Double?
        var trainingDaysPerWeek: Int?
        var targetCalories: Int?
        var targetProteinG: Int?
        var targetCarbsG: Int?
        var targetFatG: Int?
        var dietaryPreferences: [String]?

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case fitnessGoal = "fitness_goal"
            case birthYear = "birth_year"
            case heightCm = "height_cm"
            case weightKg = "weight_kg"
            case trainingDaysPerWeek = "training_days_per_week"
            case targetCalories = "target_calories"
            case targetProteinG = "target_protein_g"
            case targetCarbsG = "target_carbs_g"
            case targetFatG = "target_fat_g"
            case dietaryPreferences = "dietary_preferences"
        }
    }

    func load() async {
        guard let userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let r: ProfileRow = try await Backend.client
                .from("profiles")
                .select("display_name, fitness_goal, birth_year, height_cm, weight_kg, training_days_per_week, target_calories, target_protein_g, target_carbs_g, target_fat_g, dietary_preferences")
                .eq("id", value: userId)
                .single()
                .execute().value
            displayName = r.displayName ?? ""
            goal = r.fitnessGoal ?? "maintain"
            if let by = r.birthYear { age = Calendar.current.component(.year, from: Date()) - by }
            if let h = r.heightCm { heightCm = h }
            if let w = r.weightKg { weightKg = w }
            trainingDays = r.trainingDaysPerWeek ?? 4
            targetCalories = r.targetCalories ?? targetCalories
            targetProtein = r.targetProteinG ?? targetProtein
            targetCarbs = r.targetCarbsG ?? targetCarbs
            targetFat = r.targetFatG ?? targetFat
            dietaryPreferences = r.dietaryPreferences ?? []
        } catch {
            print("profile load failed: \(error)")
        }
    }

    /// Recompute macros from the current stats + goal, then persist.
    func recomputeAndSaveGoals() async {
        let t = TargetsCalc.compute(weightKg: weightKg, heightCm: heightCm, age: age,
                                    trainingDays: trainingDays, goal: goal)
        targetCalories = t.calories; targetProtein = t.protein
        targetCarbs = t.carbs; targetFat = t.fat
        await saveGoals()
    }

    func saveGoals() async {
        guard !isDemo, let userId else { return }
        struct Update: Codable {
            let fitness_goal: String
            let birth_year: Int
            let height_cm: Double
            let weight_kg: Double
            let training_days_per_week: Int
            let target_calories: Int
            let target_protein_g: Int
            let target_carbs_g: Int
            let target_fat_g: Int
        }
        let u = Update(fitness_goal: goal,
                       birth_year: Calendar.current.component(.year, from: Date()) - age,
                       height_cm: heightCm, weight_kg: weightKg,
                       training_days_per_week: trainingDays,
                       target_calories: targetCalories, target_protein_g: targetProtein,
                       target_carbs_g: targetCarbs, target_fat_g: targetFat)
        do { try await Backend.client.from("profiles").update(u).eq("id", value: userId).execute() }
        catch { print("save goals failed: \(error)") }
    }

    func saveDietary() async {
        guard !isDemo, let userId else { return }
        struct Update: Codable { let dietary_preferences: [String] }
        do {
            try await Backend.client.from("profiles")
                .update(Update(dietary_preferences: dietaryPreferences))
                .eq("id", value: userId).execute()
        } catch { print("save dietary failed: \(error)") }
    }
}
