import AppIntents
import Foundation

/// "Hey Siri, log a meal in AllergyFit."
///
/// Runs the same pipeline as the in-app logger — Claude identifies the foods,
/// USDA supplies every number — then speaks back an allergen verdict. The
/// verdict is the point: hands-free logging is nice, but hearing "heads up,
/// that contains dairy" before you finish eating is the safety win.
@available(iOS 16.0, *)
struct LogMealIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Meal"
    static var description = IntentDescription(
        "Describe what you ate. Volt works out the nutrition from the USDA database and checks it against your allergy triggers."
    )
    /// Stay out of the app — the whole value is logging without stopping.
    static var openAppWhenRun = false

    @Parameter(title: "What did you eat?", requestValueDialog: "What did you eat?")
    var mealDescription: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$mealDescription)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let userId = try? await Backend.client.auth.session.user.id else {
            return .result(dialog: "Open AllergyFit and sign in first, then I can log your meals.")
        }

        let slugs = SessionStore.cachedAllergenSlugs

        // estimateOnly: never stop to ask clarifying questions over voice —
        // assume standard portions instead, which is the right call hands-free.
        let response: AnalyzeMealResponse
        do {
            response = try await AIMealService.analyze(
                messages: [.init(role: "user", content: mealDescription)],
                allergens: slugs,
                estimateOnly: true)
        } catch {
            return .result(dialog: "I couldn't reach AllergyFit just now. Try again in a moment.")
        }

        guard let meal = response.meal, meal.totals.calories > 0 else {
            return .result(dialog: "I couldn't work out that meal. Try again with a bit more detail — like \"two scrambled eggs and toast\".")
        }

        let calories = Int(meal.totals.calories.rounded())
        let protein = Int(meal.totals.protein.rounded())

        let record = MealLogRecord(
            id: UUID(), userId: userId, eatenAt: Date(),
            mealType: Self.mealTypeForNow(),
            name: meal.name,
            calories: calories,
            proteinG: meal.totals.protein,
            carbsG: meal.totals.carbs,
            fatG: meal.totals.fat)
        do {
            try await Backend.client.from("meal_logs").insert(record).execute()
        } catch {
            return .result(dialog: "I worked that out but couldn't save it. Try again in a moment.")
        }

        // Fail-safe keyword scan against THIS user's triggers, same as the app.
        let ingredients = [meal.name] + meal.items.map(\.food)
        let flagged = AllergenKeywords.flagged(in: ingredients, allergens: slugs)

        if flagged.isEmpty {
            return .result(dialog: "Logged \(meal.name) — \(calories) calories, \(protein) grams of protein. Safe for your triggers.")
        }
        let list = Self.spokenList(flagged)
        return .result(dialog: "Heads up — that looks like it contains \(list). I logged it anyway: \(calories) calories, \(protein) grams of protein. Check the app before you eat.")
    }

    /// Best guess at the meal slot from the clock, matching the DB's meal_type enum.
    private static func mealTypeForNow() -> String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 4..<11: return "breakfast"
        case 11..<16: return "lunch"
        case 16..<22: return "dinner"
        default: return "snack"
        }
    }

    private static func spokenList(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + ", and " + items[items.count - 1]
        }
    }
}

/// Phrases Siri recognises without the user configuring anything.
@available(iOS 16.0, *)
struct AllergyFitShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogMealIntent(),
            phrases: [
                "Log a meal in \(.applicationName)",
                "Log what I ate in \(.applicationName)",
                "Log food in \(.applicationName)",
                "Track a meal in \(.applicationName)",
                "\(.applicationName) log a meal",
            ],
            shortTitle: "Log a Meal",
            systemImageName: "fork.knife"
        )
    }
}
