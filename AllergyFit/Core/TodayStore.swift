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
    /// Consecutive days the user has logged at least one meal.
    @Published var mealStreak = 0
    /// True once today's first meal is logged — the streak card celebrates it.
    @Published var loggedToday = false
    /// A meal pending permanent deletion — drives the Undo snackbar.
    @Published var recentlyDeleted: TodayMeal?
    private var deletedIndex: Int?
    private var deleteCommit: Task<Void, Never>?

    private var isDemo = false
    private var userId: UUID?
    private var configured = false
    private var lastSeenDay = Calendar.current.startOfDay(for: Date())

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
            mealStreak = 12
            loggedToday = true
        } else {
            Task { await refresh() }
        }
    }

    /// Water and "logged today" are per-calendar-day. If the app sits open past
    /// midnight the in-memory state is stale, so roll it over on foreground.
    func rolloverIfNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        guard today != lastSeenDay else { return }
        lastSeenDay = today
        guard !isDemo else { return }
        waterGlasses = 0
        loggedToday = false
        Task { await refresh() }
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

    /// Meal-logging streak: consecutive days with at least one meal logged.
    /// Today counts as soon as the first meal lands. If today has nothing yet the
    /// streak still shows yesterday's run — it only breaks after a full missed day.
    private func loadStreak(userId: UUID) async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let window = cal.date(byAdding: .day, value: -180, to: today) ?? today
        struct MealRow: Codable {
            let eatenAt: Date
            enum CodingKeys: String, CodingKey { case eatenAt = "eaten_at" }
        }
        do {
            let rows: [MealRow] = try await Backend.client
                .from("meal_logs")
                .select("eaten_at")
                .eq("user_id", value: userId)
                .gte("eaten_at", value: window.ISO8601Format())
                .order("eaten_at", ascending: false)
                .execute()
                .value

            let days = Set(rows.map { cal.startOfDay(for: $0.eatenAt) })
            loggedToday = days.contains(today)

            // Start at today if it's logged, else yesterday (grace for "not yet").
            var cursor = loggedToday ? today : (cal.date(byAdding: .day, value: -1, to: today) ?? today)
            var count = 0
            while days.contains(cursor) {
                count += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            }
            mealStreak = count
        } catch {
            print("streak fetch failed: \(error)")
        }
    }

    // MARK: - Mutations

    func setWater(_ glasses: Int) {
        let clamped = max(0, min(waterGoal, glasses))
        if clamped != waterGlasses { Haptics.tap() }
        waterGlasses = clamped
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
            // First meal of the day extends the streak right away — no need to
            // wait for a refresh to see it tick up.
            if !loggedToday {
                loggedToday = true
                mealStreak += 1
            }
        }
        Haptics.success()
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

    /// Forgiving delete (#9): remove immediately + show an Undo window; the DB
    /// delete only commits after a few seconds unless the user taps Undo.
    func deleteMeal(_ meal: TodayMeal) {
        guard let idx = meals.firstIndex(where: { $0.id == meal.id }) else { return }
        deletedIndex = idx
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            recentlyDeleted = meal
            meals.remove(at: idx)
        }
        Haptics.tap()
        deleteCommit?.cancel()
        deleteCommit = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.commitDelete(meal)
        }
    }

    func undoDelete() {
        guard let meal = recentlyDeleted else { return }
        deleteCommit?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            meals.insert(meal, at: min(deletedIndex ?? meals.count, meals.count))
            recentlyDeleted = nil
        }
        Haptics.tap()
    }

    private func commitDelete(_ meal: TodayMeal) async {
        withAnimation { recentlyDeleted = nil }
        guard !isDemo else { return }
        do {
            try await Backend.client.from("meal_logs").delete().eq("id", value: meal.id).execute()
        } catch {
            print("meal delete failed: \(error)")
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
