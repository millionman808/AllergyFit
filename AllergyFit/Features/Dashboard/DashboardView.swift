import SwiftUI

/// "Today" — functional daily dashboard backed by TodayStore.
struct DashboardView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var planStore: PlanStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = TodayStore()
    @StateObject private var trends = TrendsStore()
    @ObservedObject private var friendStore = FuelFriendStore.shared
    @State private var showSymptomLog = false
    @State private var showQuickAdd = false
    @State private var showTrends = false
    @State private var showNutritionScore = false
    @State private var showCycleSheet = false
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
                        topHeader
                        FuelFriendStageView(
                            friendStore: friendStore,
                            calories: store.consumedCalories,
                            targetCalories: store.dynamicTargetCalories,
                            protein: store.consumedProtein,
                            targetProtein: store.targetProtein,
                            water: store.waterGlasses,
                            waterGoal: store.waterGoal,
                            mealCount: store.meals.count,
                            allergens: session.allergensForAI
                        )
                        PipGoalsCard(
                            pip: friendStore,
                            day: daySnapshot,
                            onLogFood: onCheckFood,
                            onTummyCheckIn: { showSymptomLog = true },
                            onAddWater: {
                                store.setWater(store.waterGlasses + 1)
                                friendStore.hydrate()
                            }
                        )
                        almaMacroQuadCard
                        dailyPlanCard
                        activityAndWorkoutsCard
                        if store.isCycleTrackingActive {
                            cycleConciergeCard
                        }
                        mealsSection
                        TrendsCard(store: trends) { showTrends = true }
                        waterCard
                    }
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, Theme.Metrics.tabBarClearance)
                }
                .refreshable { await store.refresh() }

                if let deleted = store.recentlyDeleted {
                    undoSnackbar(deleted)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                store.configure(session: session)
                trends.configure(session: session, targetCalories: store.targetCalories)
            }
            .onChange(of: scenePhase) { phase in
                // Water + "logged today" are per-day; reset them if the app was
                // left open past midnight.
                if phase == .active {
                    store.rolloverIfNewDay()
                    friendStore.rolloverIfNewDay()
                }
            }
            // Meals saved from the camera, barcode or the + sheet land in the
            // database, not this store: reload so goals and totals catch up.
            .onReceive(NotificationCenter.default.publisher(for: .foodLogged)) { _ in
                Task { await store.refresh() }
            }
            .onChange(of: daySnapshot) { friendStore.syncAutomaticGoals($0) }
            .sheet(isPresented: $showSymptomLog) {
                SymptomLogView()
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddMealView { name, type, cal, p, c, f in
                    store.addMeal(name: name, mealType: type, calories: cal, protein: p, carbs: c, fat: f)
                    friendStore.feed(mealName: name)
                }
            }
            .sheet(isPresented: $showTrends) {
                TrendsView(store: trends)
            }
            .sheet(isPresented: $showNutritionScore) {
                NutritionScoreSheet(score: store.nutritionScore)
            }
            .sheet(isPresented: $showCycleSheet) {
                CycleFuelingSheet()
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

    private var daySnapshot: PipDaySnapshot {
        PipDaySnapshot(
            mealTypes: store.meals.map(\.mealType),
            water: store.waterGlasses,
            waterGoal: store.waterGoal,
            protein: store.consumedProtein,
            targetProtein: store.targetProtein,
            activeMinutes: store.todayWorkouts.reduce(0) { $0 + $1.durationMinutes }
        )
    }

    // MARK: - Top Header (Finch Style — Friend Greeting, Hearts & Streak Pill)

    private var topHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(todayDateFormatted.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.finchPeach)
                Text("Today with \(friendStore.name)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            Spacer()

            // Hearts Count from petting
            Button {
                friendStore.pet()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Colors.finchRose)
                    Text("\(friendStore.hearts)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Theme.Colors.surface, in: Capsule())
                .overlay(
                    Capsule().stroke(Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
            }
            .buttonStyle(.plain)

            // Streak Pill
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(store.loggedToday ? Theme.Colors.finchButter : Theme.Colors.textTertiary)
                Text("\(store.mealStreak)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.Colors.surface, in: Capsule())
            .overlay(
                Capsule().stroke(Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        }
        .padding(.top, 4)
    }

    private var todayDateFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    // MARK: - Finch 4-Ring Macro Row (Calories, Protein, Carbs, Fat)

    private var almaMacroQuadCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("DAILY FUEL TARGETS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text("\(store.remainingCalories.formatted()) cal left")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.volt)
            }

            HStack(spacing: 0) {
                almaRing(
                    title: "Calories",
                    current: "\(store.consumedCalories)",
                    target: "\(store.dynamicTargetCalories)",
                    unit: "",
                    progress: store.dynamicTargetCalories > 0 ? Double(store.consumedCalories) / Double(store.dynamicTargetCalories) : 0,
                    color: Theme.Colors.caloriesRing
                )

                almaRing(
                    title: "Protein",
                    current: "\(store.consumedProtein)g",
                    target: "\(store.targetProtein)g",
                    unit: "",
                    progress: store.targetProtein > 0 ? Double(store.consumedProtein) / Double(store.targetProtein) : 0,
                    color: Theme.Colors.protein
                )

                almaRing(
                    title: "Carbs",
                    current: "\(store.consumedCarbs)g",
                    target: "\(store.targetCarbs)g",
                    unit: "",
                    progress: store.targetCarbs > 0 ? Double(store.consumedCarbs) / Double(store.targetCarbs) : 0,
                    color: Theme.Colors.carbs
                )

                almaRing(
                    title: "Fat",
                    current: "\(store.consumedFat)g",
                    target: "\(store.targetFat)g",
                    unit: "",
                    progress: store.targetFat > 0 ? Double(store.consumedFat) / Double(store.targetFat) : 0,
                    color: Theme.Colors.fat
                )
            }

            if store.activeCaloriesBurned > 0 || store.cycleCalorieAdjustment > 0 {
                HStack(spacing: 12) {
                    if store.activeCaloriesBurned > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Colors.caution)
                            Text("+\(store.activeCaloriesBurned) active burn")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    if store.cycleCalorieAdjustment > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(store.cyclePhase.accentColor)
                            Text("+\(store.cycleCalorieAdjustment) hormone fuel")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .card()
    }

    private func almaRing(title: String, current: String, target: String, unit: String, progress: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: 6.5)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)

                VStack(spacing: 0) {
                    Text(current)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }
                .padding(.horizontal, 4)
            }
            .frame(width: 66, height: 66)

            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("of \(target)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var activityAndWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("TODAY'S ACTIVITY")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Theme.Colors.volt)
                Spacer()
                if store.activeCaloriesBurned > 0 {
                    Text("+\(store.activeCaloriesBurned) kcal burned")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.safe)
                }
            }

            // High-level wearable ring stats
            HStack(spacing: 8) {
                statPill(icon: "flame.fill", label: "\(store.activeCaloriesBurned) kcal", sub: "Active Burn", color: Theme.Colors.caution)
                statPill(icon: "figure.walk", label: "\(store.todaySteps.formatted())", sub: "Steps", color: Theme.Colors.volt)
                if let hr = store.currentHeartRate {
                    statPill(icon: "heart.fill", label: "\(hr) bpm", sub: "Heart Rate", color: Theme.Colors.danger)
                } else if let rhr = store.restingHeartRate {
                    statPill(icon: "heart.fill", label: "\(rhr) bpm", sub: "Resting HR", color: Theme.Colors.protein)
                }
            }

            if !store.todayWorkouts.isEmpty {
                VStack(spacing: 8) {
                    ForEach(store.todayWorkouts) { workout in
                        HStack(spacing: 12) {
                            Image(systemName: workout.icon)
                                .font(.title3)
                                .foregroundStyle(Theme.Colors.onVolt)
                                .frame(width: 40, height: 40)
                                .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.title)
                                    .font(Theme.Fonts.headline)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                HStack(spacing: 6) {
                                    Text("\(workout.durationMinutes) min")
                                    if let dist = workout.formattedDistance {
                                        Text("· \(dist)")
                                    }
                                    if let pace = workout.formattedPace {
                                        Text("· \(pace)")
                                    }
                                    Text("· \(workout.caloriesBurned) cal")
                                }
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            Spacer()
                            Text(workout.source)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                        .padding(10)
                        .background(Theme.Colors.surfaceRaised.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "figure.run")
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text("No workouts recorded yet today")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .card()
    }

    private func statPill(icon: String, label: String, sub: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(sub)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity)
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
                Text("FEED \(friendStore.name.uppercased())")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Theme.Colors.finchPeach)
                Spacer()
                if !todaysPlan.isEmpty {
                    Text("\(todaysPlan.filter(\.isCompleted).count) of \(todaysPlan.count) fed")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            if todaysPlan.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundStyle(Theme.Colors.finchPeach)
                        .frame(width: 48, height: 48)
                        .background(Theme.Colors.finchPeach.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Give \(friendStore.name) a food plan")
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Prepare nourishing meals checked against your listed triggers.")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                Button("Plan meals", action: onOpenPlan)
                    .font(Theme.Fonts.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(Theme.Colors.onVolt)
                    .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .buttonStyle(.plain)
                Button("Quick log a snack instead", action: onCheckFood)
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
                                    Image(systemName: "fork.knife")
                                }
                                Text(loggingPlanMealID == meal.id ? "Feeding..." : "Feed to \(friendStore.name)")
                            }
                            .font(Theme.Fonts.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundStyle(Theme.Colors.onVolt)
                            .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(loggingPlanMealID != nil)

                        Button("Review") { onOpenPlan() }
                            .font(Theme.Fonts.headline)
                            .frame(width: 92, height: 44)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .buttonStyle(.plain)
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.Colors.safe)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(friendStore.name) is happily fed for today!")
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("All planned meals were safely screened without trigger violations.")
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
                friendStore.feed(mealName: meal.recipe.title)
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

    private var cycleConciergeCard: some View {
        Button {
            showCycleSheet = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(store.cyclePhase.accentColor.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: store.cyclePhase.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(store.cyclePhase.accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("\(store.cyclePhase.title.uppercased()) PHASE • DAY \(store.cycleDay)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(store.cyclePhase.accentColor)

                        if store.cycleCalorieAdjustment > 0 {
                            Text("+\(store.cycleCalorieAdjustment) KCAL")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.Colors.onVolt)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(store.cyclePhase.accentColor, in: Capsule())
                        }
                    }

                    Text(store.cyclePhase.coachingSummary)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
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
                    .foregroundStyle(Theme.Colors.finchSky)
                Text("\(friendStore.name)'s Water Oasis")
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
                            .fill(Theme.Colors.finchSky)
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
                    friendStore.hydrate()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.Colors.onVolt)
                        .frame(width: 40, height: 40)
                        .background(Theme.Colors.finchSky, in: Circle())
                }
                .pressable()
            }

            // WaterLlama-style beverage picker
            HStack(spacing: 6) {
                ForEach(BeverageType.allCases) { bev in
                    Button {
                        store.logBeverage(bev)
                        friendStore.hydrate()
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: bev.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: bev.colorHex))
                            Text(bev.rawValue)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.Colors.volt)
                .frame(width: 44, height: 44)
                .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.Colors.parchmentBorder.opacity(0.6), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(meal.mealType) · \(meal.time)")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    // Quarantine Screened Tag
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 9))
                        Text("Screened Safe")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Theme.Colors.safe)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.safe.opacity(0.12), in: Capsule())
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(meal.calories)")
                    .font(Theme.Fonts.stat(18))
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

/// Bevel-style Nutrition Quality Score detail sheet.
struct NutritionScoreSheet: View {
    let score: NutritionScoreBreakdown
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Big score gauge
                        ZStack {
                            Circle()
                                .stroke(Theme.Colors.surfaceRaised, lineWidth: 14)
                            Circle()
                                .trim(from: 0, to: CGFloat(score.totalScore) / 100.0)
                                .stroke(Color(hex: score.ratingColorHex), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 2) {
                                Text("\(score.totalScore)")
                                    .font(Theme.Fonts.stat(44))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text(score.ratingLabel)
                                    .font(Theme.Fonts.headline)
                                    .foregroundStyle(Color(hex: score.ratingColorHex))
                            }
                        }
                        .frame(width: 160, height: 160)
                        .padding(.top, 16)

                        Text("Your score combines macro target accuracy, zero allergen triggers logged, meal timing cadence, and daily hydration.")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        VStack(spacing: 10) {
                            scoreRow(title: "Macro Accuracy", points: "\(score.macroScore)/40", icon: "chart.bar.fill", color: Theme.Colors.protein)
                            scoreRow(title: "Allergen Safety", points: "\(score.safetyScore)/30", icon: "checkmark.shield.fill", color: Theme.Colors.safe)
                            scoreRow(title: "Meal Cadence & Fueling", points: "\(score.balanceScore)/20", icon: "calendar", color: Theme.Colors.volt)
                            scoreRow(title: "Hydration Balance", points: "\(score.hydrationScore)/10", icon: "drop.fill", color: Color(hex: 0x38BDF8))
                        }
                        .padding(.horizontal, Theme.Metrics.screenPadding)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Nutrition Quality Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.Colors.volt)
                }
            }
        }
    }

    private func scoreRow(title: String, points: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Text(points)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .card()
    }
}

