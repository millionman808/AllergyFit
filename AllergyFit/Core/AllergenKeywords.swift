import Foundation

/// Client-side allergen keyword scan — mirrors the server safety-net so a generated
/// recipe is double-checked against the user's triggers even before the edge
/// function is redeployed. Fail-safe: over-flagging beats missing a hidden source —
/// but a naive substring match flagged "coconut milk" as dairy and "eggplant" as
/// egg, and a warning that cries wolf is one people learn to ignore. So each
/// trigger also carries the safe phrases that contain its keywords, which are
/// stripped from the text before matching.
enum AllergenKeywords {
    struct Entry {
        let name: String
        let words: [String]
        /// Phrases that contain a keyword but are NOT the allergen.
        let safe: [String]
    }

    static let map: [String: Entry] = [
        "peanut": .init(name: "Peanut", words: ["peanut"], safe: ["peanut-free"]),
        "tree_nut": .init(name: "Tree Nuts",
            words: ["almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut", "macadamia", "pine nut", "brazil nut", "praline", "marzipan"],
            safe: ["nut-free"]),
        "dairy": .init(name: "Dairy",
            words: ["milk", "butter", "cheese", "cream", "yogurt", "yoghurt", "whey", "casein", "ghee", "buttermilk", "parmesan", "mozzarella", "cheddar", "ricotta", "feta", "brie", "kefir", "custard"],
            safe: ["coconut milk", "almond milk", "oat milk", "soy milk", "rice milk", "cashew milk", "hemp milk", "pea milk", "macadamia milk", "hazelnut milk", "plant milk", "plant-based milk", "non-dairy milk", "dairy-free",
                   "coconut cream", "coconut yogurt", "coconut yoghurt", "almond yogurt", "soy yogurt", "oat yogurt", "cashew cream", "cream of tartar", "creamer",
                   "peanut butter", "almond butter", "cashew butter", "sunflower butter", "sunflower seed butter", "seed butter", "nut butter", "cocoa butter", "apple butter", "shea butter", "vegan butter", "plant butter",
                   "vegan cheese", "cashew cheese", "nutritional yeast", "cream-style corn"]),
        "egg": .init(name: "Egg", words: ["egg", "mayonnaise", "mayo", "meringue", "aioli", "albumen"],
            safe: ["eggplant", "egg-free", "vegan mayo", "vegan mayonnaise", "egg replacer", "flax egg", "chia egg"]),
        "wheat": .init(name: "Wheat",
            words: ["wheat", "flour", "bread", "breadcrumb", "pasta", "noodle", "cracker", "tortilla", "couscous", "bulgur", "semolina", "farro", "spelt", "seitan"],
            safe: ["buckwheat", "almond flour", "coconut flour", "rice flour", "oat flour", "chickpea flour", "cassava flour", "tapioca flour", "corn flour", "cornflour", "quinoa flour", "sorghum flour", "teff flour", "arrowroot flour", "potato flour", "gluten-free flour", "wheat-free", "gluten-free",
                   "rice noodle", "zucchini noodle", "sweet potato noodle", "glass noodle", "shirataki noodle", "kelp noodle", "chickpea pasta", "rice pasta", "lentil pasta", "corn pasta", "gluten-free pasta",
                   "corn tortilla", "rice cracker", "gluten-free bread", "cornbread"]),
        "gluten": .init(name: "Gluten",
            words: ["wheat", "flour", "bread", "breadcrumb", "pasta", "noodle", "barley", "rye", "soy sauce", "beer", "couscous", "seitan", "bulgur", "semolina", "farro", "spelt", "malt"],
            safe: ["buckwheat", "almond flour", "coconut flour", "rice flour", "oat flour", "chickpea flour", "cassava flour", "tapioca flour", "corn flour", "cornflour", "quinoa flour", "sorghum flour", "teff flour", "arrowroot flour", "potato flour", "gluten-free flour", "gluten-free",
                   "rice noodle", "zucchini noodle", "sweet potato noodle", "glass noodle", "shirataki noodle", "kelp noodle", "chickpea pasta", "rice pasta", "lentil pasta", "corn pasta", "gluten-free pasta",
                   "corn tortilla", "rice cracker", "gluten-free bread", "tamari", "coconut aminos", "gluten-free soy sauce", "gluten-free beer"]),
        "soy": .init(name: "Soy", words: ["soy", "soya", "tofu", "edamame", "tempeh", "miso", "tamari"], safe: ["soy-free", "coconut aminos"]),
        "fish": .init(name: "Fish", words: ["salmon", "tuna", "cod", "tilapia", "anchov", "halibut", "trout", "sardine", "fish", "mahi", "snapper", "haddock", "mackerel"],
            safe: ["fish-free", "vegan fish sauce"]),
        "shellfish": .init(name: "Shellfish", words: ["shrimp", "prawn", "crab", "lobster", "crawfish", "crayfish", "scampi", "clam", "mussel", "oyster", "scallop", "squid", "calamari"],
            safe: ["crabapple", "crab apple", "oyster mushroom", "oyster sauce"]),
        "sesame": .init(name: "Sesame", words: ["sesame", "tahini", "benne"], safe: ["sesame-free"]),
        "corn": .init(name: "Corn", words: ["corn", "cornstarch", "cornmeal", "polenta", "grits", "maize", "masa"],
            safe: ["acorn", "peppercorn", "cornish", "corn-free"]),
        "mustard": .init(name: "Mustard", words: ["mustard"], safe: ["mustard greens"]),
        "celery": .init(name: "Celery", words: ["celery", "celeriac"], safe: []),
        "sulfite": .init(name: "Sulfites", words: ["wine", "dried apricot", "sulfite", "sulphite"], safe: ["wine vinegar"]),
    ]

    /// Display names of any triggers whose keywords appear in the ingredient text.
    static func flagged(in ingredients: [String], allergens: [String]) -> [String] {
        let text = " " + ingredients.joined(separator: " ").lowercased() + " "
        var hits: [String] = []
        for slug in allergens {
            // A custom trigger ("mango", "sulphites in wine") has no entry, so
            // the typed name itself is the keyword.
            let entry = map[slug] ?? Entry(name: slug.capitalized, words: [slug.lowercased()], safe: [])
            var hay = text
            for phrase in entry.safe { hay = hay.replacingOccurrences(of: phrase, with: " ") }
            // Match at a word start so "egg" finds "eggs" but not "veggie".
            let hit = entry.words.contains { word in
                hay.range(of: "(^|[^a-z])" + NSRegularExpression.escapedPattern(for: word),
                          options: .regularExpression) != nil
            }
            if hit { hits.append(entry.name) }
        }
        return hits
    }
}
