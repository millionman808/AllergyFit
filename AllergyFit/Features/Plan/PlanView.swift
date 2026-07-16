import SwiftUI

// MARK: - Models

struct PlannedMeal: Codable, Identifiable, Equatable {
    let id: UUID
    var day: Int          // 0 = Monday … 6 = Sunday
    var recipe: Recipe
    var mealType: String? = nil   // "Breakfast" / "Lunch" / "Dinner" / "Snack"
}

struct GroceryLine: Identifiable {
    var id: String        // normalized ingredient text
    var text: String
    var count: Int
}

// MARK: - Store

/// Weekly meal plan + auto-generated grocery list.
/// Coach behavior: plan real recipes onto days, the shopping list writes itself.
@MainActor
final class PlanStore: ObservableObject {
    @Published var planned: [PlannedMeal] = [] {
        didSet { persistPlan() }
    }
    @Published var checked: Set<String> = [] {
        didSet { persistChecked() }
    }

    static let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var isDemo = true
    private var userId: UUID?
    private var configured = false
    private var syncTask: Task<Void, Never>?

    init() {
        load()
        seedForScreenshotsIfRequested()
    }

    /// Call once with the session; signed-in users load + sync via meal_plans.
    func configure(session: SessionStore) {
        guard !configured else { return }
        configured = true
        isDemo = session.isDemo
        userId = session.session?.user.id
        if !isDemo, userId != nil {
            Task { await loadFromDatabase() }
        }
    }

    /// Monday of the current week, yyyy-MM-dd (matches meal_plans.starts_on).
    static func weekStart() -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: start)
    }

    private struct PlanRow: Codable {
        let user_id: UUID
        let starts_on: String
        let days: Int
        let status: String
        let plan: [PlannedMeal]
        let grocery_list: [String]
    }

    private func loadFromDatabase() async {
        guard let userId else { return }
        struct Row: Codable { let plan: [PlannedMeal] }
        do {
            let rows: [Row] = try await Backend.client
                .from("meal_plans")
                .select("plan")
                .eq("user_id", value: userId)
                .eq("starts_on", value: Self.weekStart())
                .execute().value
            if let row = rows.first {
                planned = row.plan
            }
        } catch {
            print("plan load failed: \(error)")
        }
    }

    private func syncToDatabase() {
        guard !isDemo, let userId else { return }
        syncTask?.cancel()
        let row = PlanRow(user_id: userId, starts_on: Self.weekStart(), days: 7,
                          status: "active", plan: planned,
                          grocery_list: groceries.map(\.text))
        syncTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000) // debounce rapid edits
            guard !Task.isCancelled else { return }
            do {
                try await Backend.client.from("meal_plans")
                    .upsert(row, onConflict: "user_id,starts_on")
                    .execute()
            } catch {
                print("plan sync failed: \(error)")
            }
        }
    }

    // MARK: Plan operations

    func add(_ recipe: Recipe, to day: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            planned.append(PlannedMeal(id: UUID(), day: day, recipe: recipe))
        }
    }

    func add(_ recipe: Recipe, mealType: String, to day: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            planned.append(PlannedMeal(id: UUID(), day: day, recipe: recipe, mealType: mealType))
        }
    }

    /// Replace every meal on a day (used when Volt plans the whole day).
    func setDay(_ meals: [PlannedMeal], day: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            planned.removeAll { $0.day == day }
            planned.append(contentsOf: meals)
        }
    }

    func remove(_ meal: PlannedMeal) {
        withAnimation { planned.removeAll { $0.id == meal.id } }
    }

    func meals(for day: Int) -> [PlannedMeal] {
        planned.filter { $0.day == day }
    }

    func calories(for day: Int) -> Int {
        meals(for: day).compactMap(\.recipe.calories).reduce(0, +)
    }

    var plannedDaysCount: Int {
        Set(planned.map(\.day)).count
    }

    // MARK: Grocery list (merged across the whole week)

    var groceries: [GroceryLine] {
        var lines: [String: (text: String, count: Int)] = [:]
        for meal in planned {
            for ingredient in meal.recipe.ingredients {
                let text = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                let key = text.lowercased()
                if let existing = lines[key] {
                    lines[key] = (existing.text, existing.count + 1)
                } else {
                    lines[key] = (text, 1)
                }
            }
        }
        return lines
            .map { GroceryLine(id: $0.key, text: $0.value.text, count: $0.value.count) }
            .sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending }
    }

    func toggleChecked(_ line: GroceryLine) {
        if checked.contains(line.id) { checked.remove(line.id) } else { checked.insert(line.id) }
    }

    // MARK: Persistence (local; DB sync comes with meal_plans wiring)

    private func persistPlan() {
        if let data = try? JSONEncoder().encode(planned) {
            UserDefaults.standard.set(data, forKey: "weekPlan")
        }
        syncToDatabase()
    }

    private func persistChecked() {
        UserDefaults.standard.set(Array(checked), forKey: "groceryChecked")
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "weekPlan"),
           let decoded = try? JSONDecoder().decode([PlannedMeal].self, from: data) {
            planned = decoded
        }
        checked = Set(UserDefaults.standard.stringArray(forKey: "groceryChecked") ?? [])
    }

    private func seedForScreenshotsIfRequested() {
        guard UserDefaults.standard.bool(forKey: "seedPlan"), planned.isEmpty else { return }
        func demo(_ title: String, _ cal: Int, _ ingredients: [String]) -> Recipe {
            Recipe(title: title, url: "https://example.com/\(title)", image: "",
                   calories: cal, ingredients: ingredients, flagged: [])
        }
        planned = [
            PlannedMeal(id: UUID(), day: 2, recipe: demo("Chicken Mandi", 520,
                ["500g chicken thighs", "2 cups basmati rice", "1 onion", "2 tbsp mandi spice", "1 tbsp olive oil"])),
            PlannedMeal(id: UUID(), day: 2, recipe: demo("Beef Stir-Fry", 610,
                ["400g beef strips", "2 cups jasmine rice", "1 broccoli crown", "2 tbsp coconut aminos", "1 tbsp olive oil"])),
            PlannedMeal(id: UUID(), day: 3, recipe: demo("Salmon & Sweet Potato", 640,
                ["2 salmon fillets", "2 sweet potatoes", "1 broccoli crown", "1 tbsp olive oil"])),
        ]
    }
}

// MARK: - Plan view

struct PlanView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var planStore: PlanStore
    @State private var selectedDay: Int = {
        // default to today (Mon = 0)
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }()
    @State private var showGroceries = false
    @State private var showDayPlan = false
    @State private var dailyTarget = 2840
    var onBrowseRecipes: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Metrics.spacing) {
                dayStrip
                daySummary
                planWithVoltButton

                let meals = planStore.meals(for: selectedDay)
                if meals.isEmpty {
                    emptyState
                } else {
                    ForEach(meals) { meal in
                        PlannedMealRow(meal: meal) { planStore.remove(meal) }
                    }
                }

                groceryButton
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 24)
        }
        .task {
            let t = await DayTargets.load(session: session)
            dailyTarget = t.calories
        }
        .sheet(isPresented: $showGroceries) { GroceryListView() }
        .sheet(isPresented: $showDayPlan) {
            DayPlanView(day: selectedDay)
                .environmentObject(session)
                .environmentObject(planStore)
        }
    }

    private var planWithVoltButton: some View {
        Button { showDayPlan = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.onVolt)
                    .frame(width: 34, height: 34)
                    .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Plan \(PlanStore.dayNames[selectedDay]) with Volt")
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("A full day around \(dailyTarget) kcal, safe for your triggers")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.textTertiary)
            }
            .card()
        }
    }

    private var dayStrip: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { day in
                let count = planStore.meals(for: day).count
                Button {
                    selectedDay = day
                } label: {
                    VStack(spacing: 3) {
                        Text(PlanStore.dayNames[day])
                            .font(Theme.Fonts.caption)
                        if count > 0 {
                            Text("\(count)")
                                .font(Theme.Fonts.stat(14))
                        } else {
                            Circle()
                                .fill(day == selectedDay ? Theme.Colors.onVolt.opacity(0.35) : Theme.Colors.surfaceRaised)
                                .frame(width: 5, height: 5)
                                .padding(.vertical, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(day == selectedDay ? Theme.Colors.volt : Theme.Colors.surface)
                    .foregroundStyle(day == selectedDay ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private var daySummary: some View {
        let kcal = planStore.calories(for: selectedDay)
        let count = planStore.meals(for: selectedDay).count
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(PlanStore.dayNames[selectedDay]) — \(count) meal\(count == 1 ? "" : "s") planned")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(kcal > 0
                     ? "\(kcal) of \(dailyTarget) kcal planned"
                     : "Plan meals and the grocery list builds itself")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            if kcal > 0 {
                MacroGauge(label: "", value: Double(kcal), target: Double(dailyTarget), unit: "", color: Theme.Colors.volt)
                    .frame(width: 74)
            }
        }
        .card()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("Nothing planned for \(PlanStore.dayNames[selectedDay]) yet")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Find a recipe you like, tap the calendar icon, and pick a day.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                onBrowseRecipes()
            } label: {
                Text("Browse recipes")
                    .font(Theme.Fonts.headline)
                    .padding(.horizontal, 22)
                    .frame(height: 44)
                    .background(Theme.Colors.volt)
                    .foregroundStyle(Theme.Colors.onVolt)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .card()
    }

    private var groceryButton: some View {
        let count = planStore.groceries.count
        return Button {
            showGroceries = true
        } label: {
            HStack {
                Image(systemName: "cart.fill")
                Text(count > 0 ? "This week's list · \(count) items" : "Grocery list")
                    .font(Theme.Fonts.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(count > 0 ? Theme.Colors.volt : Theme.Colors.surfaceRaised)
            .foregroundStyle(count > 0 ? Theme.Colors.onVolt : Theme.Colors.textTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(count == 0)
        .padding(.top, 8)
    }
}

// MARK: - Planned meal row

struct PlannedMealRow: View {
    let meal: PlannedMeal
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: meal.recipe.image)) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Theme.Colors.surfaceRaised
                        .overlay(Image(systemName: "fork.knife").foregroundStyle(Theme.Colors.textTertiary))
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                if let type = meal.mealType {
                    Text(type.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.volt)
                }
                Text(meal.recipe.title)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let cal = meal.recipe.calories {
                        Text("\(cal) kcal")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Text("\(meal.recipe.ingredients.count) ingredients")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(8)
                    .background(Theme.Colors.surfaceRaised, in: Circle())
            }
        }
        .card()
    }
}

// MARK: - Grocery list (auto-generated from the week's plan)

struct GroceryListView: View {
    @EnvironmentObject var planStore: PlanStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Theme.Colors.volt)
                            Text("Built from your \(planStore.planned.count) planned meal\(planStore.planned.count == 1 ? "" : "s") this week — always verify labels when you shop")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Spacer()
                        }
                        .card()

                        ForEach(planStore.groceries) { line in
                            Button {
                                planStore.toggleChecked(line)
                            } label: {
                                HStack {
                                    Image(systemName: planStore.checked.contains(line.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(planStore.checked.contains(line.id) ? Theme.Colors.volt : Theme.Colors.textTertiary)
                                    Text(line.text)
                                        .font(Theme.Fonts.headline)
                                        .foregroundStyle(planStore.checked.contains(line.id) ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                                        .strikethrough(planStore.checked.contains(line.id), color: Theme.Colors.textTertiary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    if line.count > 1 {
                                        Text("×\(line.count)")
                                            .font(Theme.Fonts.caption)
                                            .foregroundStyle(Theme.Colors.volt)
                                    }
                                }
                                .card()
                            }
                        }
                    }
                    .padding(Theme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Grocery list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.Colors.volt)
                }
            }
        }
    }
}
