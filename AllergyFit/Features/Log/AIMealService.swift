import Foundation

// MARK: - analyze-meal edge function client + response models

struct AnalyzeMealResponse: Codable {
    var needsClarification: Bool
    var questions: [String]?
    var meal: AnalyzedMeal?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case needsClarification = "needs_clarification"
        case questions, meal, error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        needsClarification = try c.decodeIfPresent(Bool.self, forKey: .needsClarification) ?? false
        questions = try c.decodeIfPresent([String].self, forKey: .questions)
        meal = try c.decodeIfPresent(AnalyzedMeal.self, forKey: .meal)
        error = try c.decodeIfPresent(String.self, forKey: .error)
    }
}

struct AnalyzedMeal: Codable {
    var name: String
    var confidence: Double
    var items: [AnalyzedItem]
    var totals: MealTotals
    var allergens: AllergenVerdict
    var suggestions: [String]
}

struct AnalyzedItem: Codable, Identifiable, Equatable {
    var id: Int { fdcId ?? food.hashValue }
    var food: String
    var quantity: Double
    var unit: String
    var preparation: String
    var grams: Double
    var fdcId: Int?
    var fdcDescription: String?
    var needsReview: Bool
    var portionEstimated: Bool
    var allergens: [String]
    var swappable: Bool = false
    var substitutes: [String] = []
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    var sodium: Double

    enum CodingKeys: String, CodingKey {
        case food, quantity, unit, preparation, grams, allergens
        case fdcId = "fdc_id"
        case fdcDescription = "fdc_description"
        case needsReview = "needs_review"
        case portionEstimated = "portion_estimated"
        case swappable, substitutes
        case calories, protein, carbs, fat, fiber, sugar, sodium
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        food = try c.decode(String.self, forKey: .food)
        quantity = try c.decodeIfPresent(Double.self, forKey: .quantity) ?? 0
        unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? ""
        preparation = try c.decodeIfPresent(String.self, forKey: .preparation) ?? ""
        grams = try c.decodeIfPresent(Double.self, forKey: .grams) ?? 0
        fdcId = try c.decodeIfPresent(Int.self, forKey: .fdcId)
        fdcDescription = try c.decodeIfPresent(String.self, forKey: .fdcDescription)
        needsReview = try c.decodeIfPresent(Bool.self, forKey: .needsReview) ?? false
        portionEstimated = try c.decodeIfPresent(Bool.self, forKey: .portionEstimated) ?? false
        allergens = try c.decodeIfPresent([String].self, forKey: .allergens) ?? []
        swappable = try c.decodeIfPresent(Bool.self, forKey: .swappable) ?? false
        substitutes = try c.decodeIfPresent([String].self, forKey: .substitutes) ?? []
        calories = try c.decodeIfPresent(Double.self, forKey: .calories) ?? 0
        protein = try c.decodeIfPresent(Double.self, forKey: .protein) ?? 0
        carbs = try c.decodeIfPresent(Double.self, forKey: .carbs) ?? 0
        fat = try c.decodeIfPresent(Double.self, forKey: .fat) ?? 0
        fiber = try c.decodeIfPresent(Double.self, forKey: .fiber) ?? 0
        sugar = try c.decodeIfPresent(Double.self, forKey: .sugar) ?? 0
        sodium = try c.decodeIfPresent(Double.self, forKey: .sodium) ?? 0
    }

    init(food: String, quantity: Double, unit: String, preparation: String, grams: Double,
         fdcId: Int?, fdcDescription: String?, needsReview: Bool, portionEstimated: Bool,
         allergens: [String], swappable: Bool, substitutes: [String],
         calories: Double, protein: Double, carbs: Double, fat: Double,
         fiber: Double, sugar: Double, sodium: Double) {
        self.food = food; self.quantity = quantity; self.unit = unit
        self.preparation = preparation; self.grams = grams
        self.fdcId = fdcId; self.fdcDescription = fdcDescription
        self.needsReview = needsReview; self.portionEstimated = portionEstimated
        self.allergens = allergens; self.swappable = swappable; self.substitutes = substitutes
        self.calories = calories; self.protein = protein; self.carbs = carbs
        self.fat = fat; self.fiber = fiber; self.sugar = sugar; self.sodium = sodium
    }

    /// Rescale nutrition when the user edits the portion (values stay DB-derived).
    func scaled(toGrams newGrams: Double) -> AnalyzedItem {
        guard grams > 0 else { return self }
        let f = newGrams / grams
        var copy = self
        copy.grams = (newGrams * 10).rounded() / 10
        copy.calories = (calories * f * 10).rounded() / 10
        copy.protein = (protein * f * 10).rounded() / 10
        copy.carbs = (carbs * f * 10).rounded() / 10
        copy.fat = (fat * f * 10).rounded() / 10
        copy.fiber = (fiber * f * 10).rounded() / 10
        copy.sugar = (sugar * f * 10).rounded() / 10
        copy.sodium = (sodium * f * 10).rounded() / 10
        return copy
    }
}

struct MealTotals: Codable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    var sodium: Double
}

struct AllergenVerdict: Codable {
    var contains: [String]
    var safe: [String]
}

enum AIMealService {
    struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    static func analyze(messages: [ChatMessage], allergens: [String] = [], estimateOnly: Bool = false) async throws -> AnalyzeMealResponse {
        let url = Config.supabaseURL.appendingPathComponent("functions/v1/analyze-meal")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabasePublishableKey, forHTTPHeaderField: "apikey")
        if let token = try? await Backend.client.auth.session.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        struct Payload: Codable {
            let messages: [ChatMessage]
            let allergens: [String]
            let estimate_only: Bool
        }
        request.httpBody = try JSONEncoder().encode(Payload(messages: messages, allergens: allergens, estimate_only: estimateOnly))

        let (data, response) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(AnalyzeMealResponse.self, from: data)
        if let error = decoded.error {
            throw NSError(domain: "AIMealService", code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                          userInfo: [NSLocalizedDescriptionKey: error])
        }
        return decoded
    }
}

// MARK: - Mock (UI previews / screenshots via -mockMealResult 1)

extension AnalyzedMeal {
    static var mock: AnalyzedMeal {
        AnalyzedMeal(
            name: "Scrambled eggs, toast & butter",
            confidence: 0.86,
            items: [
                AnalyzedItem(food: "eggs", quantity: 2, unit: "large", preparation: "scrambled", grams: 100,
                             fdcId: 748967, fdcDescription: "Eggs, Grade A, Large, egg whole",
                             needsReview: false, portionEstimated: false, allergens: ["Egg"],
                             swappable: true, substitutes: ["JUST Egg (plant-based)", "Silken tofu scramble"],
                             calories: 148, protein: 12.5, carbs: 0.8, fat: 9.9, fiber: 0, sugar: 0.2, sodium: 129),
                AnalyzedItem(food: "sourdough bread", quantity: 1, unit: "slice", preparation: "toasted", grams: 50,
                             fdcId: 174914, fdcDescription: "Bread, sourdough",
                             needsReview: false, portionEstimated: true, allergens: ["Wheat"],
                             swappable: true, substitutes: ["Gluten-free bread", "Sweet potato toast", "Corn tortilla"],
                             calories: 144, protein: 5.9, carbs: 28.1, fat: 0.9, fiber: 1.2, sugar: 2.5, sodium: 320),
                AnalyzedItem(food: "butter", quantity: 1, unit: "tsp", preparation: "", grams: 4.7,
                             fdcId: 173410, fdcDescription: "Butter, salted",
                             needsReview: false, portionEstimated: false, allergens: ["Milk"],
                             swappable: true, substitutes: ["Olive oil", "Avocado", "Coconut oil"],
                             calories: 33.7, protein: 0, carbs: 0, fat: 3.8, fiber: 0, sugar: 0, sodium: 30),
                AnalyzedItem(food: "salt", quantity: 1, unit: "pinch", preparation: "", grams: 0.4,
                             fdcId: 173468, fdcDescription: "Salt, table",
                             needsReview: false, portionEstimated: false, allergens: [],
                             swappable: false, substitutes: [],
                             calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0, sugar: 0, sodium: 155),
            ],
            totals: MealTotals(calories: 325.7, protein: 18.4, carbs: 28.9, fat: 14.6, fiber: 1.2, sugar: 2.7, sodium: 634),
            allergens: AllergenVerdict(contains: ["Egg", "Wheat", "Milk"],
                                       safe: ["Peanut", "Tree Nut", "Soy", "Fish", "Shellfish", "Sesame"]),
            suggestions: ["Swap butter for avocado for healthier fats", "Add spinach to the eggs for extra iron"]
        )
    }
}
