import Foundation

struct GeneratedRecipe: Codable, Equatable {
    var title: String
    var description: String
    var safeNote: String
    var servings: Int
    var totalTimeMinutes: Int
    var ingredients: [Ingredient]
    var steps: [String]
    var nutritionPerServing: Nutrition
    /// Triggers the server safety-net still detected (empty when clean).
    var flagged: [String]? = nil

    struct Ingredient: Codable, Equatable, Hashable {
        var amount: String
        var name: String
    }
    struct Nutrition: Codable, Equatable {
        var calories: Int
        var protein: Int
        var carbs: Int
        var fat: Int
    }

    enum CodingKeys: String, CodingKey {
        case title, description, servings, ingredients, steps, flagged
        case safeNote = "safe_note"
        case totalTimeMinutes = "total_time_minutes"
        case nutritionPerServing = "nutrition_per_serving"
    }

    /// Combine the server verdict with a local keyword scan against the user's triggers.
    func flags(for allergens: [String]) -> [String] {
        var set = flagged ?? []
        let local = AllergenKeywords.flagged(in: ingredients.map(\.name), allergens: allergens)
        for f in local where !set.contains(f) { set.append(f) }
        return set
    }

    /// Convert to a plannable/savable Recipe (no photo — AI-generated).
    func asRecipe(flagged flags: [String] = []) -> Recipe {
        Recipe(
            title: title,
            url: "ai://\(UUID().uuidString)",
            image: "",
            calories: nutritionPerServing.calories,
            ingredients: ingredients.map { "\($0.amount) \($0.name)" },
            flagged: flags,
            directions: steps,
            protein: nutritionPerServing.protein,
            carbs: nutritionPerServing.carbs,
            fat: nutritionPerServing.fat,
            servings: servings
        )
    }
}

enum RecipeGenService {
    struct Response: Codable {
        var recipe: GeneratedRecipe?
        var error: String?
    }

    static func generate(request: String, allergens: [String], dietary: [String], goal: String) async throws -> GeneratedRecipe {
        let url = Config.supabaseURL.appendingPathComponent("functions/v1/generate-recipe")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Config.supabasePublishableKey, forHTTPHeaderField: "apikey")
        struct Body: Codable { let request: String; let allergens: [String]; let dietary: [String]; let goal: String }
        req.httpBody = try JSONEncoder().encode(Body(request: request, allergens: allergens, dietary: dietary, goal: goal))

        let (data, response) = try await URLSession.shared.data(for: req)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        if let error = decoded.error {
            throw NSError(domain: "RecipeGen", code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                          userInfo: [NSLocalizedDescriptionKey: error])
        }
        guard let recipe = decoded.recipe else {
            throw NSError(domain: "RecipeGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "No recipe returned."])
        }
        return recipe
    }
}

// MARK: - Mock (screenshot verification via -mockRecipe 1)

extension GeneratedRecipe {
    static var mock: GeneratedRecipe {
        GeneratedRecipe(
            title: "15-Minute Chicken & Sweet Potato Scramble Bowl",
            description: "A hearty, satisfying breakfast bowl packed with lean protein and complex carbs to fuel muscle building — all dairy, peanut, and sesame free.",
            safeNote: "This recipe avoids peanut, dairy, and sesame by using olive oil instead of butter or sesame oil, with no hidden nut or dairy products.",
            servings: 2,
            totalTimeMinutes: 15,
            ingredients: [
                .init(amount: "1 tbsp", name: "extra-virgin olive oil"),
                .init(amount: "8 oz", name: "lean ground chicken"),
                .init(amount: "1 medium", name: "sweet potato, peeled and grated"),
                .init(amount: "4 large", name: "eggs, beaten"),
                .init(amount: "2 cups", name: "fresh baby spinach"),
                .init(amount: "1/2 tsp", name: "garlic powder"),
                .init(amount: "1/2 tsp", name: "smoked paprika"),
                .init(amount: "1/4 tsp", name: "salt"),
            ],
            steps: [
                "Heat the olive oil in a large nonstick skillet over medium-high heat.",
                "Add the ground chicken and cook, breaking it up, until browned — about 4 minutes.",
                "Stir in the grated sweet potato, garlic powder, and paprika. Cook 4 minutes until tender.",
                "Push everything to one side, pour in the beaten eggs, and scramble until just set.",
                "Fold in the spinach until wilted, season with salt, and serve warm.",
            ],
            nutritionPerServing: .init(calories: 420, protein: 38, carbs: 22, fat: 21)
        )
    }
}
