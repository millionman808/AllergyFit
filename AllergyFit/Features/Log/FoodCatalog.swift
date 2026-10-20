import SwiftUI

// MARK: - Food model

/// One food the logger can show: a common food, something you logged before,
/// a favorite, or a USDA lookup result. Nutrients are per base serving
/// (`servingUnits[0]`); the detail screen scales them by portion.
struct FoodCatalogItem: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    let name: String
    var brand: String? = nil
    var icon: String = "fork.knife"
    let baseCalories: Int
    let baseProtein: Double
    let baseCarbs: Double
    let baseFat: Double
    var fiber: Double? = nil
    var sugar: Double? = nil
    var sodium: Double? = nil          // mg
    var allergenInfo: AllergenInfo = .unknown
    var servingUnits: [ServingUnit]
    /// Where the numbers came from, shown on the detail screen.
    var source: String = "USDA FoodData Central"

    struct ServingUnit: Hashable, Codable {
        let name: String
        let gramWeight: Int
        let multiplier: Double
    }

    /// What we know about this food's allergens.
    enum AllergenInfo: Hashable, Codable {
        /// Known allergen slugs (dairy, egg, wheat...) for curated foods.
        case slugs([String])
        /// Already checked against the user's triggers by the server; these matched.
        case checked(hits: [String])
        /// Not checked (e.g. a quick-add someone typed in).
        case unknown
    }

    /// Name-based key, stable across launches (ids are not).
    var key: String { name.lowercased().trimmingCharacters(in: .whitespaces) }

    // MARK: Triggers

    func triggerHits(_ triggers: [String]) -> [String] {
        switch allergenInfo {
        case .slugs(let s):
            let mine = Set(triggers.map { $0.lowercased() })
            return s.filter { mine.contains($0.lowercased()) }
        case .checked(let hits):
            return hits
        case .unknown:
            return []
        }
    }

    var allergensKnown: Bool {
        if case .unknown = allergenInfo { return false }
        return true
    }

    func safetySummary(allergens triggers: [String]) -> String {
        let hits = triggerHits(triggers)
        if !hits.isEmpty { return "Contains your trigger: \(hits.map { $0.capitalized }.joined(separator: ", "))" }
        if !allergensKnown { return "Not checked against your triggers. Read the label." }
        return triggers.isEmpty ? "No common allergens listed" : "None of your triggers found"
    }

    // MARK: Labels worked out from the numbers (per portion)

    func positiveTraits(scale: Double) -> [String] {
        var out: [String] = []
        let kcal = Double(baseCalories) * scale
        let protein = baseProtein * scale
        if protein >= 10 { out.append("High in protein (\(Int(protein.rounded()))g)") }
        if let f = fiber.map({ $0 * scale }), f >= 3 { out.append("Good source of fiber (\(Int(f.rounded()))g)") }
        if let s = sodium.map({ $0 * scale }), s <= 140 { out.append("Low sodium") }
        if let s = sugar.map({ $0 * scale }), s <= 2.5, kcal > 0 { out.append("Low sugar") }
        if kcal > 0 && kcal <= 100 { out.append("Under 100 kcal") }
        return out
    }

    func cautionTraits(allergens triggers: [String], scale: Double = 1) -> [String] {
        var out = triggerHits(triggers).map { "Contains \($0.capitalized) (your trigger)" }
        if !allergensKnown { out.append("Not checked for your triggers") }
        if let s = sugar.map({ $0 * scale }), s >= 12 { out.append("High in sugar (\(Int(s.rounded()))g)") }
        if let s = sodium.map({ $0 * scale }), s >= 600 { out.append("High in sodium (\(Int(s.rounded()))mg)") }
        if baseFat * scale >= 20 { out.append("High in fat (\(Int((baseFat * scale).rounded()))g)") }
        if Double(baseCalories) * scale >= 600 { out.append("Calorie dense") }
        return out
    }

    /// Standard portion choices around a base serving of `grams`.
    static func units(base: String, grams: Int) -> [ServingUnit] {
        var u = [ServingUnit(name: base, gramWeight: grams, multiplier: 1)]
        u.append(ServingUnit(name: "Half portion", gramWeight: grams / 2, multiplier: 0.5))
        u.append(ServingUnit(name: "Double portion", gramWeight: grams * 2, multiplier: 2))
        if grams > 0 && grams != 100 {
            u.append(ServingUnit(name: "100 g", gramWeight: 100, multiplier: 100 / Double(grams)))
        }
        return u
    }

    // MARK: Common foods (USDA FoodData Central, SR Legacy values)

    static let common: [FoodCatalogItem] = [
        FoodCatalogItem(name: "Avocado, raw", icon: "leaf.fill",
                        baseCalories: 160, baseProtein: 2.0, baseCarbs: 8.5, baseFat: 14.7,
                        fiber: 6.7, sugar: 0.7, sodium: 7, allergenInfo: .slugs([]),
                        servingUnits: units(base: "Half avocado (100 g)", grams: 100)),
        FoodCatalogItem(name: "Chicken breast, roasted", icon: "fork.knife",
                        baseCalories: 165, baseProtein: 31.0, baseCarbs: 0, baseFat: 3.6,
                        fiber: 0, sugar: 0, sodium: 74, allergenInfo: .slugs([]),
                        servingUnits: units(base: "1 portion (100 g)", grams: 100)),
        FoodCatalogItem(name: "Egg, hard-boiled", icon: "oval.fill",
                        baseCalories: 78, baseProtein: 6.3, baseCarbs: 0.6, baseFat: 5.3,
                        fiber: 0, sugar: 0.6, sodium: 62, allergenInfo: .slugs(["egg"]),
                        servingUnits: units(base: "1 large egg (50 g)", grams: 50)),
        FoodCatalogItem(name: "Greek yogurt, plain nonfat", icon: "cup.and.saucer.fill",
                        baseCalories: 100, baseProtein: 17.3, baseCarbs: 6.1, baseFat: 0.7,
                        fiber: 0, sugar: 5.5, sodium: 61, allergenInfo: .slugs(["dairy"]),
                        servingUnits: units(base: "1 container (170 g)", grams: 170)),
        FoodCatalogItem(name: "Broccoli, cooked", icon: "leaf.circle.fill",
                        baseCalories: 55, baseProtein: 3.7, baseCarbs: 11.2, baseFat: 0.6,
                        fiber: 5.1, sugar: 2.2, sodium: 64, allergenInfo: .slugs([]),
                        servingUnits: units(base: "1 cup chopped (156 g)", grams: 156)),
        FoodCatalogItem(name: "White rice, cooked", icon: "circle.grid.3x3.fill",
                        baseCalories: 205, baseProtein: 4.3, baseCarbs: 44.5, baseFat: 0.4,
                        fiber: 0.6, sugar: 0.1, sodium: 2, allergenInfo: .slugs([]),
                        servingUnits: units(base: "1 cup (158 g)", grams: 158)),
        FoodCatalogItem(name: "Banana", icon: "moon.fill",
                        baseCalories: 105, baseProtein: 1.3, baseCarbs: 27.0, baseFat: 0.4,
                        fiber: 3.1, sugar: 14.4, sodium: 1, allergenInfo: .slugs([]),
                        servingUnits: units(base: "1 medium (118 g)", grams: 118)),
        FoodCatalogItem(name: "Salmon, baked", icon: "fish.fill",
                        baseCalories: 206, baseProtein: 22.1, baseCarbs: 0, baseFat: 12.4,
                        fiber: 0, sugar: 0, sodium: 61, allergenInfo: .slugs(["fish"]),
                        servingUnits: units(base: "1 fillet (100 g)", grams: 100)),
    ]
}

// MARK: - Favorites (saved on this device)

@MainActor
final class FavoriteFoods: ObservableObject {
    static let shared = FavoriteFoods()
    @Published private(set) var items: [FoodCatalogItem] = []
    private let storeKey = "favoriteFoodsV1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let list = try? JSONDecoder().decode([FoodCatalogItem].self, from: data) {
            items = list
        }
    }

    func contains(_ food: FoodCatalogItem) -> Bool { items.contains { $0.key == food.key } }

    func toggle(_ food: FoodCatalogItem) {
        if contains(food) { items.removeAll { $0.key == food.key } } else { items.insert(food, at: 0) }
        if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: storeKey) }
    }
}

// MARK: - Recents (what you actually logged)

@MainActor
final class RecentFoods: ObservableObject {
    static let shared = RecentFoods()
    @Published private(set) var items: [FoodCatalogItem] = []
    @Published private(set) var isLoading = false
    private var loadedFor: UUID?

    private struct Row: Decodable {
        let name: String
        let calories: Int?
        let protein_g: Double?
        let carbs_g: Double?
        let fat_g: Double?
        let fiber_g: Double?
        let sugar_g: Double?
        let sodium_mg: Double?
        let detected_allergens: [String]?
        let confidence: Double?
    }

    /// Distinct foods from the last 80 logs, newest first. Demo mode uses today's sample meals.
    func load(session: SessionStore, today: TodayStore, force: Bool = false) async {
        guard !session.isDemo, let userId = session.session?.user.id else {
            items = today.meals.reversed().map { meal in
                FoodCatalogItem(name: meal.name, icon: meal.icon, baseCalories: meal.calories,
                                baseProtein: Double(meal.protein), baseCarbs: Double(meal.carbs),
                                baseFat: Double(meal.fat),
                                servingUnits: FoodCatalogItem.units(base: "1 portion (as logged)", grams: 0),
                                source: "Your log")
            }
            return
        }
        if !force, loadedFor == userId, !items.isEmpty { return }
        isLoading = items.isEmpty
        defer { isLoading = false }
        do {
            let rows: [Row] = try await Backend.client
                .from("meal_logs")
                .select("name, calories, protein_g, carbs_g, fat_g, fiber_g, sugar_g, sodium_mg, detected_allergens, confidence")
                .eq("user_id", value: userId)
                .order("eaten_at", ascending: false)
                .limit(80)
                .execute()
                .value
            var seen = Set<String>()
            var out: [FoodCatalogItem] = []
            for r in rows {
                let k = r.name.lowercased().trimmingCharacters(in: .whitespaces)
                guard !k.isEmpty, seen.insert(k).inserted else { continue }
                // AI-analyzed logs carry a confidence and were checked against triggers.
                let info: FoodCatalogItem.AllergenInfo = r.confidence != nil
                    ? .checked(hits: r.detected_allergens ?? []) : .unknown
                out.append(FoodCatalogItem(
                    name: r.name, baseCalories: r.calories ?? 0,
                    baseProtein: r.protein_g ?? 0, baseCarbs: r.carbs_g ?? 0, baseFat: r.fat_g ?? 0,
                    fiber: r.fiber_g, sugar: r.sugar_g, sodium: r.sodium_mg, allergenInfo: info,
                    servingUnits: FoodCatalogItem.units(base: "1 portion (as logged)", grams: 0),
                    source: "Your log"))
                if out.count == 25 { break }
            }
            items = out
            loadedFor = userId
        } catch {
            print("recent foods load failed: \(error)")
        }
    }
}

// MARK: - USDA lookup by name

enum FoodLookup {
    enum LookupError: LocalizedError {
        case notFound
        var errorDescription: String? { "Couldn't find that food. Try a simpler name, like \"turkey sandwich\"." }
    }

    /// Looks a typed food up through the analyze-meal function: the AI only
    /// identifies the food and portion; every number comes from USDA FoodData Central.
    static func lookup(_ query: String, triggers: [String]) async throws -> FoodCatalogItem {
        let response = try await AIMealService.analyze(
            messages: [.init(role: "user", content: query)],
            allergens: triggers,
            estimateOnly: true)
        guard let meal = response.meal, meal.totals.calories > 0 else { throw LookupError.notFound }
        let grams = Int(meal.items.reduce(0) { $0 + $1.grams }.rounded())
        let base = grams > 0 ? "1 serving (~\(grams) g)" : "1 serving"
        return FoodCatalogItem(
            name: meal.name.isEmpty ? query.capitalized : meal.name,
            baseCalories: Int(meal.totals.calories.rounded()),
            baseProtein: meal.totals.protein, baseCarbs: meal.totals.carbs, baseFat: meal.totals.fat,
            fiber: meal.totals.fiber, sugar: meal.totals.sugar, sodium: meal.totals.sodium,
            allergenInfo: .checked(hits: meal.allergens.contains),
            servingUnits: FoodCatalogItem.units(base: base, grams: grams))
    }
}
