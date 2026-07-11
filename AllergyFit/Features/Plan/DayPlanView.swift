import SwiftUI
import Supabase

// MARK: - Targets

/// The daily numbers Volt plans against — pulled from the user's profile.
struct DayTargets {
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var goal: String
    var dietary: [String]

    static let fallback = DayTargets(calories: 2840, protein: 180, carbs: 320, fat: 84,
                                     goal: "build", dietary: [])

    @MainActor
    static func load(session: SessionStore) async -> DayTargets {
        guard !session.isDemo, let userId = session.session?.user.id else { return .fallback }
        struct Row: Codable {
            let targetCalories: Int?, targetProteinG: Int?, targetCarbsG: Int?, targetFatG: Int?
            let fitnessGoal: String?, dietaryPreferences: [String]?
            enum CodingKeys: String, CodingKey {
                case targetCalories = "target_calories"
                case targetProteinG = "target_protein_g"
                case targetCarbsG = "target_carbs_g"
                case targetFatG = "target_fat_g"
                case fitnessGoal = "fitness_goal"
                case dietaryPreferences = "dietary_preferences"
            }
        }
        do {
            let row: Row = try await Backend.client.from("profiles")
                .select("target_calories, target_protein_g, target_carbs_g, target_fat_g, fitness_goal, dietary_preferences")
                .eq("id", value: userId).single().execute().value
            return DayTargets(
                calories: row.targetCalories ?? fallback.calories,
                protein: row.targetProteinG ?? fallback.protein,
                carbs: row.targetCarbsG ?? fallback.carbs,
                fat: row.targetFatG ?? fallback.fat,
                goal: row.fitnessGoal ?? fallback.goal,
                dietary: row.dietaryPreferences ?? []
            )
        } catch {
            print("targets load failed: \(error)")
            return .fallback
        }
    }
}

// MARK: - Service

enum MealSlot: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .breakfast: return "cup.and.saucer.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        }
    }
    /// Share of the daily calorie/protein budget.
    var fraction: Double {
        switch self {
        case .breakfast: return 0.30
        case .lunch: return 0.30
        case .dinner: return 0.30
        case .snack: return 0.10
        }
    }
}

enum DayPlanService {
    static func generate(slot: MealSlot, targets: DayTargets, allergens: [String]) async throws -> GeneratedRecipe {
        let cals = Int((Double(targets.calories) * slot.fraction).rounded())
        let protein = Int((Double(targets.protein) * slot.fraction).rounded())
        let request = "A \(slot.title.lowercased()) of about \(cals) calories with roughly \(protein)g of protein. Keep it realistic for that meal."
        return try await RecipeGenService.generate(
            request: request, allergens: allergens, dietary: targets.dietary, goal: targets.goal)
    }

    /// Generate every meal for the day in parallel.
    static func generateDay(targets: DayTargets, allergens: [String]) async throws -> [MealSlot: GeneratedRecipe] {
        try await withThrowingTaskGroup(of: (MealSlot, GeneratedRecipe).self) { group in
            for slot in MealSlot.allCases {
                group.addTask { (slot, try await generate(slot: slot, targets: targets, allergens: allergens)) }
            }
            var out: [MealSlot: GeneratedRecipe] = [:]
            for try await (slot, recipe) in group { out[slot] = recipe }
            return out
        }
    }
}

// MARK: - View

struct DayPlanView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var planStore: PlanStore
    @Environment(\.dismiss) private var dismiss

    @State var day: Int
    @State private var targets: DayTargets = .fallback
    @State private var meals: [MealSlot: GeneratedRecipe] = [:]
    @State private var regenerating: Set<MealSlot> = []
    @State private var phase: Phase = .loading
    @State private var errorMessage: String?

    enum Phase { case loading, ready, failed }

    private var totalCalories: Int { meals.values.reduce(0) { $0 + $1.nutritionPerServing.calories } }
    private var totalProtein: Int { meals.values.reduce(0) { $0 + $1.nutritionPerServing.protein } }
    private var onTarget: Bool { abs(totalCalories - targets.calories) <= max(200, Int(Double(targets.calories) * 0.08)) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Metrics.spacing) {
                        switch phase {
                        case .loading: loadingCard
                        case .failed: failedCard
                        case .ready:
                            summaryCard
                            ForEach(MealSlot.allCases) { slot in
                                if let recipe = meals[slot] { mealCard(slot, recipe) }
                            }
                            addButton
                        }
                    }
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Plan \(PlanStore.dayNames[day])")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }.foregroundStyle(Theme.Colors.textSecondary)
                }
                if phase == .ready {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { Task { await generateAll() } } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .foregroundStyle(Theme.Colors.volt)
                    }
                }
            }
            .task { await start() }
        }
    }

    // MARK: Cards

    private var loadingCard: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large).tint(Theme.Colors.volt)
            Text("Volt is building your \(PlanStore.dayNames[day]) around \(targets.calories) kcal…")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Text("Breakfast · Lunch · Dinner · Snack, all safe for your triggers")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    private var failedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36)).foregroundStyle(Theme.Colors.caution)
            Text("Couldn't build the plan")
                .font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
            if let errorMessage {
                Text(errorMessage).font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary).multilineTextAlignment(.center)
            }
            Button("Try again") { Task { await generateAll() } }
                .font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.volt)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 50).card()
    }

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(totalCalories) kcal · \(totalProtein)g protein")
                    .font(Theme.Fonts.title).foregroundStyle(Theme.Colors.textPrimary)
                Text("Target \(targets.calories) kcal · \(targets.protein)g")
                    .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Label(onTarget ? "On target" : "Close",
                  systemImage: onTarget ? "checkmark.seal.fill" : "arrow.up.arrow.down")
                .font(Theme.Fonts.caption.weight(.semibold))
                .foregroundStyle(onTarget ? Theme.Colors.safe : Theme.Colors.caution)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background((onTarget ? Theme.Colors.safe : Theme.Colors.caution).opacity(0.15), in: Capsule())
        }
        .card()
    }

    private func mealCard(_ slot: MealSlot, _ recipe: GeneratedRecipe) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: slot.icon)
                    .font(.subheadline).foregroundStyle(Theme.Colors.onVolt)
                    .frame(width: 30, height: 30)
                    .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(slot.title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text(recipe.title)
                        .font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if regenerating.contains(slot) {
                    ProgressView().tint(Theme.Colors.volt)
                } else {
                    Button { Task { await regenerate(slot) } } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(Theme.Colors.volt)
                    }
                }
            }
            HStack(spacing: 14) {
                macro("\(recipe.nutritionPerServing.calories)", "kcal")
                macro("\(recipe.nutritionPerServing.protein)g", "protein")
                macro("\(recipe.nutritionPerServing.carbs)g", "carbs")
                macro("\(recipe.nutritionPerServing.fat)g", "fat")
            }
            .padding(.top, 2)

            let flags = recipe.flags(for: session.allergenSlugs)
            if !flags.isEmpty {
                Label("May contain \(flags.joined(separator: ", ")) — tap regenerate",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.danger)
            }
        }
        .card()
    }

    private func macro(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(Theme.Fonts.stat(15)).foregroundStyle(Theme.Colors.textPrimary)
            Text(label).font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var addButton: some View {
        Button {
            addToPlan()
        } label: {
            Text("Add this day to my plan")
                .font(Theme.Fonts.headline)
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(Theme.Colors.volt)
                .foregroundStyle(Theme.Colors.onVolt)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.top, 4)
    }

    // MARK: Actions

    private func start() async {
        targets = await DayTargets.load(session: session)
        await generateAll()
    }

    private func generateAll() async {
        phase = .loading
        errorMessage = nil
        do {
            meals = try await DayPlanService.generateDay(targets: targets, allergens: session.allergenSlugs)
            phase = .ready
        } catch {
            errorMessage = error.localizedDescription
            phase = .failed
        }
    }

    private func regenerate(_ slot: MealSlot) async {
        regenerating.insert(slot)
        defer { regenerating.remove(slot) }
        do {
            let recipe = try await DayPlanService.generate(slot: slot, targets: targets, allergens: session.allergenSlugs)
            withAnimation { meals[slot] = recipe }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addToPlan() {
        let planned = MealSlot.allCases.compactMap { slot -> PlannedMeal? in
            guard let recipe = meals[slot] else { return nil }
            let flags = recipe.flags(for: session.allergenSlugs)
            return PlannedMeal(id: UUID(), day: day, recipe: recipe.asRecipe(flagged: flags), mealType: slot.title)
        }
        planStore.setDay(planned, day: day)
        dismiss()
    }
}
