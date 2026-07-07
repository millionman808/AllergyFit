import Foundation

// MARK: - Database records (match supabase/migrations/001_initial_schema.sql)

struct MealLogRecord: Codable, Identifiable {
    var id: UUID
    var userId: UUID
    var eatenAt: Date
    var mealType: String
    var name: String
    var calories: Int?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case eatenAt = "eaten_at"
        case mealType = "meal_type"
        case name
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
    }
}

struct DailyMetricsRecord: Codable {
    var userId: UUID
    var date: String          // yyyy-MM-dd
    var waterMl: Int
    var isTrainingDay: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case date
        case waterMl = "water_ml"
        case isTrainingDay = "is_training_day"
    }
}

struct ProfileTargets: Codable {
    var targetCalories: Int?
    var targetProteinG: Int?
    var targetCarbsG: Int?
    var targetFatG: Int?

    enum CodingKeys: String, CodingKey {
        case targetCalories = "target_calories"
        case targetProteinG = "target_protein_g"
        case targetCarbsG = "target_carbs_g"
        case targetFatG = "target_fat_g"
    }
}

// MARK: - UI model

struct TodayMeal: Identifiable, Equatable {
    let id: UUID
    var name: String
    var mealType: String     // display name, e.g. "Pre-workout"
    var time: String
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var icon: String

    static func icon(for mealType: String) -> String {
        switch mealType.lowercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_") {
        case "breakfast": return "cup.and.saucer.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.stars.fill"
        case "pre_workout": return "bolt.fill"
        case "post_workout": return "bolt.badge.clock.fill"
        default: return "fork.knife"
        }
    }
}
