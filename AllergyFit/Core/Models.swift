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

// MARK: - Workouts & Health models

struct WorkoutRecord: Codable, Identifiable {
    var id: UUID
    var userId: UUID
    var startedAt: Date
    var workoutType: String
    var durationMinutes: Int
    var intensity: String
    var caloriesBurned: Int?
    var distanceMeters: Double?
    var avgHeartRate: Int?
    var source: String?
    var externalId: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startedAt = "started_at"
        case workoutType = "workout_type"
        case durationMinutes = "duration_minutes"
        case intensity
        case caloriesBurned = "calories_burned"
        case distanceMeters = "distance_meters"
        case avgHeartRate = "avg_heart_rate"
        case source
        case externalId = "external_id"
        case notes
    }
}

struct StrengthSet: Identifiable, Codable, Equatable {
    var id = UUID()
    var exerciseName: String
    var setNumber: Int
    var weightLb: Double
    var reps: Int
}

struct HealthWorkoutSummary: Identifiable, Equatable {
    let id: UUID
    var title: String
    var activityType: String
    var startDate: Date
    var durationMinutes: Int
    var caloriesBurned: Int
    var distanceMeters: Double?
    var avgHeartRate: Int?
    var source: String
    var icon: String

    var formattedDistance: String? {
        guard let m = distanceMeters, m > 0 else { return nil }
        let miles = m / 1609.344
        return String(format: "%.2f mi", miles)
    }

    var formattedPace: String? {
        guard let m = distanceMeters, m > 0, durationMinutes > 0 else { return nil }
        let miles = m / 1609.344
        guard miles > 0.05 else { return nil }
        let paceMinutes = Double(durationMinutes) / miles
        let mins = Int(paceMinutes)
        let secs = Int((paceMinutes - Double(mins)) * 60)
        return String(format: "%d:%02d /mi", mins, secs)
    }

    static func icon(for type: String) -> String {
        switch type.lowercased() {
        case "running", "run": return "figure.run"
        case "cycling", "cycle", "biking": return "figure.outdoor.cycle"
        case "lifting", "traditionalstrengthtraining", "functionalstrengthtraining": return "dumbbell.fill"
        case "swimming", "swim": return "figure.pool.swim"
        case "walking", "walk", "hiking": return "figure.walk"
        case "hiit", "crossfit", "highintensityintervaltraining": return "flame.fill"
        case "yoga", "mindandbody": return "figure.mind.and.body"
        default: return "figure.mixed.cardio"
        }
    }
}

/// JEFIT-style playful volume comparisons to tangible heavy objects.
enum LiftedVolumeComparison {
    struct Metaphor {
        let name: String
        let symbol: String
        let weightLb: Double
        let funFact: String
    }

    static let milestones: [Metaphor] = [
        Metaphor(name: "Grand Piano", symbol: "pianokeys", weightLb: 1000, funFact: "a concert Steinway Model D"),
        Metaphor(name: "Harley Motorcycle", symbol: "bicycle", weightLb: 2500, funFact: "a cruising Harley-Davidson"),
        Metaphor(name: "Adult Giraffe", symbol: "pawprint.fill", weightLb: 4200, funFact: "a full-grown bull giraffe"),
        Metaphor(name: "Tesla Model Y", symbol: "bolt.car.fill", weightLb: 8800, funFact: "an electric dual-motor crossover"),
        Metaphor(name: "African Bush Elephant", symbol: "pawprint.fill", weightLb: 13000, funFact: "the largest land animal on Earth"),
        Metaphor(name: "T-Rex", symbol: "lizard.fill", weightLb: 18000, funFact: "an apex Cretaceous predator"),
        Metaphor(name: "London Double-Decker Bus", symbol: "bus.fill", weightLb: 28000, funFact: "a classic red Routemaster"),
        Metaphor(name: "Semi Truck Cab", symbol: "truck.box.fill", weightLb: 45000, funFact: "a heavy-duty highway hauler"),
        Metaphor(name: "Blue Whale", symbol: "fish.fill", weightLb: 120000, funFact: "the heaviest creature to ever exist")
    ]

    static func compare(totalVolumeLb: Double) -> (metaphor: Metaphor, count: Double) {
        guard totalVolumeLb > 0 else {
            return (milestones[0], 0)
        }
        var best = milestones[0]
        for m in milestones {
            if totalVolumeLb >= m.weightLb {
                best = m
            } else {
                break
            }
        }
        let count = (totalVolumeLb / best.weightLb * 10).rounded() / 10
        return (best, count)
    }
}

/// WaterLlama-style beverage types with hydration factors.
enum BeverageType: String, CaseIterable, Identifiable {
    case water = "Water"
    case electrolytes = "Electrolytes"
    case proteinShake = "Protein Shake"
    case greenTea = "Green Tea"
    case coffee = "Coffee"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .electrolytes: return "bolt.fill"
        case .proteinShake: return "cup.and.saucer.fill"
        case .greenTea: return "leaf.fill"
        case .coffee: return "mug.fill"
        }
    }

    var colorHex: UInt {
        switch self {
        case .water: return 0x38BDF8
        case .electrolytes: return 0x5FF2C2
        case .proteinShake: return 0x60A5FA
        case .greenTea: return 0x34D399
        case .coffee: return 0xD97706
        }
    }

    var hydrationFactor: Double {
        switch self {
        case .water: return 1.0
        case .electrolytes: return 1.1
        case .proteinShake: return 0.8
        case .greenTea: return 0.95
        case .coffee: return 0.85
        }
    }
}

/// Bevel-style Daily Nutrition Quality Score (0–100).
struct NutritionScoreBreakdown: Equatable {
    var totalScore: Int
    var macroScore: Int       // 0-40
    var safetyScore: Int      // 0-30
    var balanceScore: Int     // 0-20
    var hydrationScore: Int   // 0-10

    var ratingLabel: String {
        switch totalScore {
        case 90...100: return "Elite Fuel"
        case 75..<90: return "Optimal"
        case 60..<75: return "Solid"
        default: return "Needs Fuel"
        }
    }

    var ratingColorHex: UInt {
        switch totalScore {
        case 80...100: return 0x5FF2C2
        case 60..<80: return 0xFBBF24
        default: return 0xF87171
        }
    }
}

