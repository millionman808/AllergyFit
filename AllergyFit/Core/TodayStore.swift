import Foundation
import SwiftUI
import Supabase

/// Live state for the Today dashboard.
/// Demo mode: in-memory. Signed in: reads/writes Supabase.
@MainActor
final class TodayStore: ObservableObject {
    @Published var meals: [TodayMeal] = []
    @Published var waterGlasses = 0
    @Published var isTrainingDay = true
    @Published var targetCalories = 2840
    @Published var targetProtein = 180
    @Published var targetCarbs = 320
    @Published var targetFat = 84
    @Published var isLoading = false
    /// Days since the user's most recent symptom check-in (or since they started
    /// logging, if they've never logged a reaction).
    @Published var reactionFreeStreak = 0
    @Published var hasReactionHistory = false

    private var isDemo = false
    private var userId: UUID?
    private var configured = false

    let waterGoal = 8

    // MARK: - Derived

    var consumedCalories: Int { meals.reduce(0) { $0 + $1.calories } }
    var consumedProtein: Int { meals.reduce(0) { $0 + $1.protein } }
    var consumedCarbs: Int { meals.reduce(0) { $0 + $1.carbs } }
    var consumedFat: Int { meals.reduce(0) { $0 + $1.fat } }
    var remainingCalories: Int { max(0, targetCalories - consumedCalories) }

    // MARK: - Setup

    func configure(session: SessionStore) {
        guard !configured else { return }
        configured = true
        isDemo = session.isDemo
        userId = session.session?.user.id
        if isDemo {
            meals = MockData.todayMeals.map {
                TodayMeal(id: UUID(), name: $0.name, mealType: $0.mealType, time: $0.time,
                          calories: $0.calories, protein: $0.protein, carbs: $0.carbs, fat: $0.fat, icon: $0.icon)
            }
            waterGlasses = 5
            reactionFreeStreak = 12
            hasReactionHistory = true
        } else {
            Task { await refresh() }
        }
    }

    // MARK: - Load (signed-in)

    func refresh() async {
        guard !isDemo, let userId else { return }
        isLoading = true
        defer { isLoading = false }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        do {
            let records: [MealLogRecord] = try await Backend.client
                .from("meal_logs")
                .select("id, user_id, eaten_at, meal_type, name, calories, protein_g, carbs_g, fat_g")
                .eq("user_id", value: userId)
                .gte("eaten_at", value: startOfDay.ISO8601Format())
                .order("eaten_at", ascending: true)
                .execute()
                .value
            meals = records.map { r in
                TodayMeal(
                    id: r.id,
                    name: r.name,
                    mealType: Self.displayMealType(r.mealType),
                    time: r.eatenAt.formatted(date: .omitted, time: .shortened),
                    calories: r.calories ?? 0,
                    protein: Int(r.proteinG ?? 0),
                    carbs: Int(r.carbsG ?? 0),
                    fat: Int(r.fatG ?? 0),
                    icon: TodayMeal.icon(for: r.mealType)
                )
            }
        } catch {
            print("meal fetch failed: \(error)")
        }

        do {
            let targets: ProfileTargets = try await Backend.client
                .from("profiles")
                .select("target_calories, target_protein_g, target_carbs_g, target_fat_g")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            if let c = targets.targetCalories { targetCalories = c }
            if let p = targets.targetProteinG { targetProtein = p }
            if let cb = targets.targetCarbsG { targetCarbs = cb }
            if let f = targets.targetFatG { targetFat = f }
        } catch {
            print("targets fetch failed: \(error)")
        }

        do {
            struct WaterRow: Codable {
                let waterMl: Int
                let isTrainingDay: Bool?
                enum CodingKeys: String, CodingKey {
                    case waterMl = "water_ml"
                    case isTrainingDay = "is_training_day"
                }
            }
            let rows: [WaterRow] = try await Backend.client
                .from("daily_metrics")
                .select("water_ml, is_training_day")
                .eq("user_id", value: userId)
                .eq("date", value: Self.todayString())
                .execute()
                .value
            if let row = rows.first {
                waterGlasses = row.waterMl / 250
                isTrainingDay = row.isTrainingDay ?? true
            } else {
                waterGlasses = 0
            }
        } catch {
            print("water fetch failed: \(error)")
        }

        await loadStreak(userId: userId)
    }

    /// Real reaction-free streak: whole days since the last symptom check-in.
    /// If the user has never logged a reaction, count days since their first meal log.
    private func loadStreak(userId: UUID) async {
        let cal = Calendar.current
        func wholeDays(since date: Date) -> Int {
            max(0, cal.dateComponents([.day], from: cal.startOfDay(for: date),
                                      to: cal.startOfDay(for: Date())).day ?? 0)
        }
        do {
            struct SymptomRow: Codable {
                let occurredAt: Date
                enum CodingKeys: String, CodingKey { case occurredAt = "occurred_at" }
            }
            let last: [SymptomRow] = try await Backend.client
                .from("symptom_logs")
                .select("occurred_at")
                .eq("user_id", value: userId)
                .order("occurred_at", ascending: false)
                .limit(1)
                .execute()
                .value
            if let lastReaction = last.first?.occurredAt {
                reactionFreeStreak = wholeDays(since: lastReaction)
                hasReactionHistory = true
                return
            }
            // No reactions ever — measure from their first logged meal.
            struct MealRow: Codable {
                let eatenAt: Date
                enum CodingKeys: String, CodingKey { case eatenAt = "eaten_at" }
            }
            let first: [MealRow] = try await Backend.client
                .from("meal_logs")
                .select("eaten_at")
                .eq("user_id", value: userId)
                .order("eaten_at", ascending: true)
                .limit(1)
                .execute()
                .value
            reactionFreeStreak = first.first.map { wholeDays(since: $0.eatenAt) } ?? 0
            hasReactionHistory = false
        } catch {
            print("streak fetch failed: \(error)")
        }
    }

    // MARK: - Mutations

    func setWater(_ glasses: Int) {
        waterGlasses = max(0, min(waterGoal, glasses))
        guard !isDemo, let userId else { return }
        let record = DailyMetricsRecord(userId: userId, date: Self.todayString(),
                                        waterMl: waterGlasses * 250, isTrainingDay: isTrainingDay)
        Task {
            do {
                try await Backend.client
                    .from("daily_metrics")
                    .upsert(record, onConflict: "user_id,date")
                    .execute()
            } catch {
                print("water save failed: \(error)")
            }
        }
    }

    func addMeal(name: String, mealType: String, calories: Int, protein: Int, carbs: Int, fat: Int) {
        let dbType = Self.dbMealType(mealType)
        let meal = TodayMeal(id: UUID(), name: name, mealType: mealType,
                             time: Date().formatted(date: .omitted, time: .shortened),
                             calories: calories, protein: protein, carbs: carbs, fat: fat,
                             icon: TodayMeal.icon(for: dbType))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            meals.append(meal)
        }
        guard !isDemo, let userId else { return }
        let record = MealLogRecord(id: meal.id, userId: userId, eatenAt: Date(), mealType: dbType,
                                   name: name, calories: calories, proteinG: Double(protein),
                                   carbsG: Double(carbs), fatG: Double(fat))
        Task {
            do {
                try await Backend.client.from("meal_logs").insert(record).execute()
            } catch {
                print("meal save failed: \(error)")
            }
        }
    }

    func deleteMeal(_ meal: TodayMeal) {
        withAnimation { meals.removeAll { $0.id == meal.id } }
        guard !isDemo else { return }
        Task {
            do {
                try await Backend.client.from("meal_logs").delete().eq("id", value: meal.id).execute()
            } catch {
                print("meal delete failed: \(error)")
            }
        }
    }

    // MARK: - Helpers

    static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: Date())
    }

    static func dbMealType(_ display: String) -> String {
        display.lowercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_")
    }

    static func displayMealType(_ db: String) -> String {
        switch db {
        case "pre_workout": return "Pre-workout"
        case "post_workout": return "Post-workout"
        default: return db.capitalized
        }
    }
}
