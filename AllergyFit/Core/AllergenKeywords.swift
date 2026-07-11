import Foundation

/// Client-side allergen keyword scan — mirrors the server safety-net so a generated
/// recipe is double-checked against the user's triggers even before the edge
/// function is redeployed. Fail-safe: over-flagging beats missing a hidden source.
enum AllergenKeywords {
    static let map: [String: (name: String, words: [String])] = [
        "peanut": ("Peanut", ["peanut"]),
        "tree_nut": ("Tree Nuts", ["almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut", "macadamia", "pine nut", "brazil nut", "praline"]),
        "dairy": ("Dairy", ["milk", "butter", "cheese", "cream", "yogurt", "whey", "casein", "ghee", "buttermilk", "parmesan", "mozzarella", "cheddar", "ricotta"]),
        "egg": ("Egg", ["egg", "mayonnaise", "mayo", "meringue", "aioli"]),
        "wheat": ("Wheat", ["wheat", "flour", "bread", "breadcrumb", "pasta", "noodle", "cracker", "tortilla", "couscous"]),
        "gluten": ("Gluten", ["wheat", "flour", "bread", "breadcrumb", "pasta", "noodle", "barley", "rye", "soy sauce", "beer", "couscous", "seitan"]),
        "soy": ("Soy", ["soy", "tofu", "edamame", "tempeh", "miso"]),
        "fish": ("Fish", ["salmon", "tuna", "cod", "tilapia", "anchov", "halibut", "trout", "sardine", "fish"]),
        "shellfish": ("Shellfish", ["shrimp", "prawn", "crab", "lobster", "crawfish", "scampi"]),
        "sesame": ("Sesame", ["sesame", "tahini"]),
        "corn": ("Corn", ["corn", "cornstarch", "cornmeal", "polenta", "grits"]),
        "mustard": ("Mustard", ["mustard"]),
        "celery": ("Celery", ["celery"]),
        "sulfite": ("Sulfites", ["wine", "dried apricot"]),
    ]

    /// Display names of any triggers whose keywords appear in the ingredient text.
    static func flagged(in ingredients: [String], allergens: [String]) -> [String] {
        let hay = ingredients.joined(separator: " ").lowercased()
        var hits: [String] = []
        for slug in allergens {
            if let entry = map[slug], entry.words.contains(where: { hay.contains($0) }) {
                hits.append(entry.name)
            }
        }
        return hits
    }
}
