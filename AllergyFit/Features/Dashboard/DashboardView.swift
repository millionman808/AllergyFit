import SwiftUI

/// "Today" — functional daily dashboard backed by TodayStore.
struct DashboardView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var planStore: PlanStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = TodayStore()
    @StateObject private var trends = TrendsStore()
    @State private var showQuickAdd = false
    @State private var showTrends = false
    @State private var loggingPlanMealID: UUID?
    @State private var planLogError: String?
    var onOpenPlan: () -> Void = {}
    var onCheckFood: () -> Void = {}

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Metrics.spacing) {
                        greetingRow
                        dailyPlanCard
                        calorieCard
                        macroRow
                        mealsSection
                        TrendsCard(store: trends) { showTrends = true }
                        streakCard
                        waterCard
                    }
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.bottom, Theme.Metrics.tabBarClearance)
                }
                .refreshable { await store.refresh() }

                if let deleted = store.recentlyDeleted {
                    undoSnackbar(deleted)
                }
            }
            .navigationTitle("Today")
            .onAppear {
                store.configure(session: session)
                trends.configure(session: session, targetCalories: store.targetCalories)
            }
            .onChange(of: scenePhase) { phase in
                // Water + "logged today" are per-day; reset them if the app was
                // left open past midnight.
                if phase == .active { store.rolloverIfNewDay() }
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddMealView { name, type, cal, p, c, f in
                    store.addMeal(name: name, mealType: type, calories: cal, protein: p, carbs: c, fat: f)
                }
            }
            .sheet(isPresented: $showTrends) {
                TrendsView(store: trends)
            }
            .alert("Couldn't log that meal", isPresented: Binding(
                get: { planLogError != nil },
                set: { if !$0 { planLogError = nil } }
            )) {
                Button("OK", role: .cancel) { planLogError = nil }
            } message: {
                Text(planLogError ?? "Try again in a moment.")
            }
        }
    }

    /// Time-aware personal greeting (#25 Delight).
    private var greetingRow: some View {
        HStack {
            Text(greeting)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
        }
        .padding(.top, 2)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 5..<12: base = "Good morning"
        case 12..<17: base = "Good afternoon"
        default: base = "Good evening"
        }
        let name = session.isDemo
            ? MockData.userName
            : (UserDefaults.standard.string(forKey: "displayName") ?? "")
        let first = name.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "\(base) — eat with confidence today" : "\(base), \(first) — eat with confidence today"
    }

    private var todayIndex: Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }

    private var todaysPlan: [PlannedMeal] {
        planStore.meals(for: todayIndex)
    }

    private var nextPlannedMeal: PlannedMeal? {
        todaysPlan.first { !$0.isCompleted }
    }

    /// A meal runway makes the product loop visible before calories. Each dot
    /// represents a planned meal and fills as it is logged.
    private var dailyPlanCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("TODAY'S PLAN")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Theme.Colors.volt)
                Spacer()
                if !todaysPlan.isEmpty {
                    Text("\(todaysPlan.filter(\.isCompleted).count) of \(todaysPlan.count) eaten")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            if todaysPlan.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundStyle(Theme.Colors.volt)
                        .frame(width: 48, height: 48)
                        .background(Theme.Colors.volt.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Give today a food plan")
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Volt can build meals around your targets and listed triggers.")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                Button("Plan today", action: onOpenPlan)
                    .font(Theme.Fonts.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(Theme.Colors.onVolt)
                    .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .buttonStyle(.plain)
                Button("Check a meal instead", action: onCheckFood)
                    .font(Theme.Fonts.caption.weight(.bold))
                    .foregroundStyle(Theme.Colors.volt)
                    .buttonStyle(.plain)
            } else {
                mealRunway
                if let meal = nextPlannedMeal {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("UP NEXT\(meal.mealType.map { " · \($0.uppercased())" } ?? "")")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textTertiary)
                        Text(meal.recipe.title)
                            .font(Theme.Fonts.title)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(mealFitSummary(meal))
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    HStack(spacing: 10) {
                        Button {
                            logPlannedMeal(meal)
                        } label: {
                            HStack(spacing: 7) {
                                if loggingPlanMealID == meal.id {
                                    ProgressView().tint(Theme.Colors.onVolt)
                                } else {
                                    Image(systemName: "checkmark")
                                }
                                Text(loggingPlanMealID == meal.id ? "Logging" : "Log as eaten")
                            }
                            .font(Theme.Fonts.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundStyle(Theme.Colors.onVolt)
                            .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(loggingPlanMealID != nil)

                        Button("Review") { onOpenPlan() }
                            .font(Theme.Fonts.headline)
                            .frame(width: 92, height: 44)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .buttonStyle(.plain)
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.Colors.safe)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today's plan is complete")
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("Your logged meals can now contribute to weekly insights.")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                }
            }
        }
        .card()
    }

    private var mealRunway: some View {
        HStack(spacing: 6) {
            ForEach(Array(todaysPlan.enumerated()), id: \.element.id) { index, meal in
                ZStack {
                    Circle()
                        .fill(meal.isCompleted ? Theme.Colors.volt : Theme.Colors.surfaceRaised)
                        .frame(width: 30, height: 30)
                    Image(systemName: meal.isCompleted ? "checkmark" : TodayMeal.icon(for: meal.mealType ?? "snack"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(meal.isCompleted ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                }
                .accessibilityLabel("\(meal.mealType ?? "Meal") \(meal.isCompleted ? "logged" : "planned")")
                if index < todaysPlan.count - 1 {
                    Capsule()
                        .fill(meal.isCompleted ? Theme.Colors.volt.opacity(0.65) : Theme.Colors.surfaceRaised)
                        .frame(height: 3)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: todaysPlan)
    }

    private func mealFitSummary(_ meal: PlannedMeal) -> String {
        var parts: [String] = []
        if let calories = meal.recipe.calories { parts.append("\(calories) kcal") }
        if let protein = meal.recipe.protein { parts.append("\(protein)g protein") }
        parts.append("Check the current label before eating")
        return parts.joined(separator: " · ")
    }

    private func logPlannedMeal(_ meal: PlannedMeal) {
        loggingPlanMealID = meal.id
        Task {
            let success = await planStore.logAsEaten(meal)
            if success {
                if session.isDemo {
                    store.addMeal(
                        name: meal.recipe.title,
                        mealType: meal.mealType ?? "Snack",
                        calories: meal.recipe.calories ?? 0,
                        protein: meal.recipe.protein ?? 0,
                        carbs: meal.recipe.carbs ?? 0,
                        fat: meal.recipe.fat ?? 0
                    )
                } else {
                    await store.refresh()
                }
            } else {
                planLogError = "The meal stayed in your plan. Check your connection and try again."
            }
            loggingPlanMealID = nil
        }
    }

    private func undoSnackbar(_ meal: TodayMeal) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Text("Removed \(meal.name)")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Spacer()
                Button { store.undoDelete() } label: {
                    Text("Undo")
                        .font(Theme.Fonts.caption.weight(.bold))
                        .foregroundStyle(Theme.Colors.volt)
                }
                .pressable()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Theme.Colors.surface, in: Capsule())
            .overlay(Capsule().stroke(Theme.Colors.surfaceRaised, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 12)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var safetyBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title3)
                .foregroundStyle(Theme.Colors.safe)
            VStack(alignment: .leading, spacing: 2) {
                Text("Listed trigger check")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("\(store.meals.count) meal\(store.meals.count == 1 ? "" : "s") logged · Verify labels before eating")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            if store.isTrainingDay {
                Label("Training", systemImage: "bolt.fill")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.onVolt)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.volt, in: Capsule())
            }
        }
        .card()
    }

    private var calorieCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                budgetRow("flame.fill", "Budget", store.targetCalories, Theme.Colors.volt)
                budgetRow("fork.knife", "Eaten", store.consumedCalories, Theme.Colors.protein)
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(Theme.Colors.surfaceRaised, lineWidth: 12)
                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(progress > 1 ? Theme.Colors.caution : Theme.Colors.volt,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: progress)
                VStack(spacing: 0) {
                    Text("You can eat")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("\(store.remainingCalories.formatted())")
                        .font(Theme.Fonts.stat(30))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .contentTransition(.numericText())
                    Text("cal left")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .frame(width: 132, height: 132)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private func budgetRow(_ icon: String, _ label: String, _ value: Int, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                Text("\(value.formatted()) cal").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
            }
        }
    }

    private var progress: Double {
        guard store.targetCalories > 0 else { return 0 }
        return Double(store.consumedCalories) / Double(store.targetCalories)
    }

    private var macroRow: some View {
        HStack(spacing: Theme.Metrics.spacing) {
            MacroGauge(label: "Protein", value: Double(store.consumedProtein), target: Double(store.targetProtein), unit: "g", color: Theme.Colors.protein)
            MacroGauge(label: "Carbs", value: Double(store.consumedCarbs), target: Double(store.targetCarbs), unit: "g", color: Theme.Colors.carbs)
            MacroGauge(label: "Fat", value: Double(store.consumedFat), target: Double(store.targetFat), unit: "g", color: Theme.Colors.fat)
        }
    }

    private var streakCard: some View {
        HStack {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(store.loggedToday ? Theme.Colors.volt : Theme.Colors.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Logging streak")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(streakSubtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(store.mealStreak)")
                    .font(Theme.Fonts.stat(36))
                    .foregroundStyle(store.loggedToday ? Theme.Colors.volt : Theme.Colors.textTertiary)
                    .contentTransition(.numericText())
                Text(store.mealStreak == 1 ? "day" : "days")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .card()
    }

    private var streakSubtitle: String {
        if store.mealStreak == 0 { return "Log a meal to start your streak" }
        if store.loggedToday { return "Logged today — streak updated" }
        return "Log your first meal to keep it alive"
    }

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
            HStack {
                Text("Logged today")
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Button {
                    showQuickAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.Colors.volt)
                }
            }
            if store.meals.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text("Nothing logged yet — tap + to add your first meal")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .card()
            } else {
                ForEach(store.meals) { meal in
                    MealRow(meal: meal)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deleteMeal(meal)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .padding(.top, 8)
    }

    private var waterCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.protein)
                Text("Water")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text("\(store.waterGlasses)")
                    .font(Theme.Fonts.stat(20))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .contentTransition(.numericText())
                Text("of \(store.waterGoal) glasses")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            HStack(spacing: 12) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Colors.surfaceRaised)
                        Capsule()
                            .fill(Theme.Colors.protein)
                            .frame(width: geo.size.width * waterProgress)
                            .animation(.spring(response: 0.4), value: store.waterGlasses)
                    }
                }
                .frame(height: 10)
                Button {
                    store.setWater(store.waterGlasses - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(Theme.Colors.surfaceRaised, in: Circle())
                }
                .disabled(store.waterGlasses == 0)
                .opacity(store.waterGlasses == 0 ? 0.4 : 1)
                Button {
                    store.setWater(store.waterGlasses + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.Colors.onVolt)
                        .frame(width: 40, height: 40)
                        .background(Theme.Colors.protein, in: Circle())
                }
                .pressable()
            }
        }
        .card()
    }

    private var waterProgress: Double {
        guard store.waterGoal > 0 else { return 0 }
        return min(1, Double(store.waterGlasses) / Double(store.waterGoal))
    }
}

struct MealRow: View {
    let meal: TodayMeal

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: meal.icon)
                .font(.title3)
                .foregroundStyle(Theme.Colors.volt)
                .frame(width: 42, height: 42)
                .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(meal.name)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text("\(meal.mealType) · \(meal.time)")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(meal.calories)")
                    .font(Theme.Fonts.stat(17))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("kcal")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .card()
    }
}

struct MacroGauge: View {
    let label: String
    let value: Double
    let target: Double
    var unit: String = ""
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: target > 0 ? min(value / target, 1) : 0)
                    .stroke(color, style: .init(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.4), value: value)
                VStack(spacing: 0) {
                    Text("\(Int(value))")
                        .font(Theme.Fonts.stat(17))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .contentTransition(.numericText())
                    Text("of \(Int(target))\(unit)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .frame(width: 68, height: 68)
            Text(label)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}
