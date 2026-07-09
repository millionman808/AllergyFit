import Foundation

/// Single source of truth for daily targets (Mifflin-St Jeor, sex-neutral midpoint).
enum TargetsCalc {
    static func compute(weightKg: Double, heightCm: Double, age: Int,
                        trainingDays: Int, goal: String) -> (calories: Int, protein: Int, carbs: Int, fat: Int) {
        let bmr = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 78
        let activity: Double = trainingDays <= 1 ? 1.375 : trainingDays <= 3 ? 1.5 : trainingDays <= 5 ? 1.65 : 1.75
        var calories = bmr * activity
        switch goal {
        case "cut": calories -= 400
        case "build": calories += 300
        default: break
        }
        let protein = Int((weightKg * 1.9).rounded())
        let fat = Int((weightKg * 0.9).rounded())
        let carbs = max(Int(((calories - Double(protein * 4) - Double(fat * 9)) / 4).rounded()), 0)
        return (Int(calories.rounded()), protein, carbs, fat)
    }
}

/// Allergen slug ↔ display-name catalog (matches the seeded allergens table).
enum AllergenCatalog {
    static let nameBySlug: [String: String] = [
        "peanut": "Peanut", "tree_nut": "Tree Nuts", "dairy": "Milk / Dairy",
        "egg": "Egg", "wheat": "Wheat", "gluten": "Gluten", "soy": "Soy",
        "fish": "Fish", "shellfish": "Shellfish", "sesame": "Sesame",
        "corn": "Corn", "nightshade": "Nightshades", "histamine": "Histamine",
        "fodmap": "FODMAPs", "sulfite": "Sulfites", "mustard": "Mustard",
        "celery": "Celery", "lupin": "Lupin", "mollusc": "Molluscs",
        "alpha_gal": "Alpha-gal",
    ]

    static let slugByName: [String: String] =
        Dictionary(uniqueKeysWithValues: nameBySlug.map { ($0.value, $0.key) })

    static func names(for slugs: [String]) -> [String] {
        slugs.map { nameBySlug[$0] ?? $0.capitalized }
    }
}
