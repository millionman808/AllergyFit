import Foundation

/// Fills in a recipe's missing macros by running its ingredient list through the
/// existing analyze-meal / USDA FoodData Central pipeline, then dividing the
/// whole-recipe totals down to a per-serving figure.
enum RecipeNutritionService {

    static func fill(_ recipe: Recipe, replaceCalories: Bool = false) async throws -> Recipe {
        let list = recipe.ingredients
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !list.isEmpty else {
            throw err("This recipe has no ingredients to estimate from.")
        }

        let prompt = """
        Compute the nutrition for this full list of recipe ingredients. Treat it as the whole recipe (all servings combined), not a single portion:
        \(list.joined(separator: "\n"))
        """
        let resp = try await AIMealService.analyze(
            messages: [.init(role: "user", content: prompt)],
            estimateOnly: true
        )
        guard let totals = resp.meal?.totals, totals.calories > 0 else {
            throw err("Couldn't estimate nutrition from these ingredients. Try a recipe with clearer amounts.")
        }

        // How many servings to divide the whole-recipe totals by.
        let servings = servingCount(for: recipe, totalCalories: totals.calories)
        let div = Double(max(servings, 1))

        var updated = recipe
        updated.protein = Int((totals.protein / div).rounded())
        updated.carbs = Int((totals.carbs / div).rounded())
        updated.fat = Int((totals.fat / div).rounded())
        // Fill calories from USDA when asked to verify (AI estimates), or when the
        // source never provided them. Otherwise keep a trusted per-serving figure
        // (e.g. Spoonacular's) rather than overwriting it.
        if replaceCalories || updated.calories == nil {
            updated.calories = Int((totals.calories / div).rounded())
        }
        if updated.servings == nil { updated.servings = servings }
        return updated
    }

    /// Prefer the recipe's own serving count; otherwise infer it from the ratio
    /// of computed whole-recipe calories to the known per-serving calories, so
    /// the per-serving macros stay consistent with the calorie number on screen.
    private static func servingCount(for recipe: Recipe, totalCalories: Double) -> Int {
        if let s = recipe.servings, s > 0 { return s }
        if let perServing = recipe.calories, perServing > 0, totalCalories > 0 {
            return max(1, Int((totalCalories / Double(perServing)).rounded()))
        }
        return 1
    }

    private static func err(_ message: String) -> NSError {
        NSError(domain: "RecipeNutrition", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
