import Foundation

struct ScannedProduct {
    var barcode: String
    var name: String
    var brand: String?
    var imageURL: String?
    var productAllergenSlugs: [String]     // everything the product contains
    var flaggedSlugs: [String]             // intersection with the user's triggers
    var caloriesPer100g: Int?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
    var servingSizeText: String?

    var isSafe: Bool { flaggedSlugs.isEmpty }
}

enum BarcodeService {
    /// Open Food Facts allergen tag → AllergyFit slug.
    static let tagToSlug: [String: String] = [
        "milk": "dairy", "eggs": "egg", "peanuts": "peanut",
        "nuts": "tree_nut", "tree-nuts": "tree_nut", "soybeans": "soy",
        "gluten": "gluten", "cereals-containing-gluten": "gluten",
        "fish": "fish", "crustaceans": "shellfish", "molluscs": "mollusc",
        "sesame-seeds": "sesame", "mustard": "mustard", "celery": "celery",
        "sulphur-dioxide-and-sulphites": "sulfite", "lupin": "lupin",
    ]

    struct OFFResponse: Decodable {
        let status: Int
        let product: OFFProduct?
    }
    struct OFFProduct: Decodable {
        let productName: String?
        let brands: String?
        let imageFrontSmallURL: String?
        let allergensTags: [String]?
        let tracesTags: [String]?
        let servingSize: String?
        let nutriments: OFFNutriments?
        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case brands
            case imageFrontSmallURL = "image_front_small_url"
            case allergensTags = "allergens_tags"
            case tracesTags = "traces_tags"
            case servingSize = "serving_size"
            case nutriments
        }
    }
    struct OFFNutriments: Decodable {
        let energyKcal100g: Double?
        let proteins100g: Double?
        let carbohydrates100g: Double?
        let fat100g: Double?
        enum CodingKeys: String, CodingKey {
            case energyKcal100g = "energy-kcal_100g"
            case proteins100g = "proteins_100g"
            case carbohydrates100g = "carbohydrates_100g"
            case fat100g = "fat_100g"
        }
    }

    /// Looks a barcode up in Open Food Facts and computes the allergy verdict.
    static func lookup(barcode: String, userAllergens: [String]) async throws -> ScannedProduct? {
        let fields = "product_name,brands,image_front_small_url,allergens_tags,traces_tags,serving_size,nutriments"
        let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=\(fields)")!
        var request = URLRequest(url: url)
        request.setValue("AllergyFit/0.1 (iOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(OFFResponse.self, from: data)
        guard decoded.status == 1, let p = decoded.product else { return nil }

        // Collect contains + traces, map to our slugs.
        let rawTags = (p.allergensTags ?? []) + (p.tracesTags ?? [])
        let slugs = Set(rawTags.compactMap { tag -> String? in
            let key = tag.replacingOccurrences(of: "en:", with: "")
            return tagToSlug[key]
        })
        let flagged = slugs.filter { userAllergens.contains($0) }

        let n = p.nutriments
        return ScannedProduct(
            barcode: barcode,
            name: (p.productName?.isEmpty == false ? p.productName! : "Unknown product"),
            brand: p.brands,
            imageURL: p.imageFrontSmallURL,
            productAllergenSlugs: Array(slugs).sorted(),
            flaggedSlugs: Array(flagged).sorted(),
            caloriesPer100g: n?.energyKcal100g.map { Int($0.rounded()) },
            proteinPer100g: n?.proteins100g,
            carbsPer100g: n?.carbohydrates100g,
            fatPer100g: n?.fat100g,
            servingSizeText: p.servingSize
        )
    }
}
