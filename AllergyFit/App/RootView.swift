import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var purchases: PurchasesManager
    @AppStorage("seenPreAuthOnboarding") private var seenPreAuth = false
    #if DEBUG
    private static let forcePaywall = UserDefaults.standard.bool(forKey: "forcePaywall")
    #else
    private static let forcePaywall = false
    #endif
    @State private var startInSignUpMode = true

    var body: some View {
        Group {
            if Self.forcePaywall {
                // Debug only: `-forcePaywall YES` previews the gate without signing in.
                PaywallView(source: "debug")
            } else if session.isDemo && session.demoOnboarded {
                MainTabView()
            } else if !seenPreAuth {
                // High-converting funnel: answers -> calculation -> account creation -> single-screen paywall
                PreAuthOnboardingView(
                    onFinish: {
                        seenPreAuth = true
                    },
                    onSignIn: {
                        startInSignUpMode = false
                        seenPreAuth = true
                    }
                )
            } else if session.isLoading {
                // Returning users: wait for the saved session instead of
                // flashing the sign-in screen. New users never see this (the
                // onboarding branch above comes first).
                splash
            } else if session.session != nil && session.backendError && session.profileOnboarded == nil {
                OfflineView(retry: { await session.retry() })
            } else if session.isDemo && !session.demoOnboarded {
                PreAuthOnboardingView(onFinish: {
                    seenPreAuth = true
                })
            } else if session.session != nil && session.profileOnboarded == nil {
                splash // profile state loading
            } else if session.session != nil && session.profileOnboarded == false {
                PreAuthOnboardingView(onFinish: {
                    seenPreAuth = true
                })
            } else if session.isSignedIn {
                membershipGate
            } else {
                // Backing out returns to onboarding rather than trapping people on a login wall.
                AuthView(onBack: { seenPreAuth = false }, startInSignUpMode: startInSignUpMode)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.isSignedIn)
        .animation(.easeInOut(duration: 0.25), value: purchases.hasPremiumAccess)
    }

    /// Hard paywall: the app opens only with an active trial, subscription or
    /// lifetime unlock. Waits for RevenueCat's answer first so a subscriber
    /// never sees the paywall flash on launch.
    @ViewBuilder private var membershipGate: some View {
        if session.isDemo || purchases.hasPremiumAccess {
            MainTabView()
        } else if !purchases.customerInfoLoaded {
            splash
        } else {
            PaywallView(source: "gate")
        }
    }

    private var splash: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            VStack(spacing: 10) {
                Image("pip_happy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                Text("SafeFuel")
                    .font(Theme.Fonts.stat(36))
                    .foregroundStyle(Theme.Colors.volt)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var session: SessionStore
    @State private var selection = UserDefaults.standard.integer(forKey: "initialTab")
    @AppStorage("seenVoltIntro") private var seenVoltIntro = false
    @State private var showVoltIntro = false
    @State private var showQuickActionSheet = UserDefaults.standard.bool(forKey: "quickAction")
    // Shared stores
    @StateObject private var planStore = PlanStore()
    @StateObject private var todayStore = TodayStore()

    var body: some View {
        content
            .environmentObject(planStore)
            .environmentObject(todayStore)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(selection: $selection)
            }
            .sheet(isPresented: $showQuickActionSheet) {
                AlmaQuickActionSheet()
            }
            // Goal confetti, above every tab.
            .overlay { PipConfettiLayer() }
            .onAppear {
                planStore.configure(session: session)
                todayStore.configure(session: session)
            }
            .task {
                if !seenVoltIntro {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    showVoltIntro = true
                }
            }
            .sheet(isPresented: $showVoltIntro, onDismiss: {
                seenVoltIntro = true
                Task { await AdAttribution.requestTrackingIfNeeded() }
            }) {
                VoltIntroSheet()
            }
    }

    @ViewBuilder private var content: some View {
        switch selection {
        case 1:
            if Config.newMealsTabEnabled {
                MealsTab(store: todayStore, onLogFood: { showQuickActionSheet = true })
            } else {
                PlanTab()
            }
        case 2:
            GoalsTab(store: todayStore, onLogFood: { showQuickActionSheet = true })
        case 3:
            PlantTab()
        case 4:
            ProfileView()
        default:
            DashboardView(
                store: todayStore,
                onOpenPlan: { selection = 1 },
                onCheckFood: { showQuickActionSheet = true },
                onOpenGoals: { selection = 2 }
            )
        }
    }
}

// MARK: - Figma Screen 3 & 4 (Meals & Planner Tab)

struct MealsTab: View {
    @ObservedObject var store: TodayStore
    @EnvironmentObject var planStore: PlanStore
    var onLogFood: () -> Void = {}

    @State private var searchText = ""
    @State private var selectedFilter = 0 // 0: Recent, 1: Meals, 2: Favorites
    @State private var selectedDayIndex = 2 // 0: Mon, 1: Tue, 2: Wed, ...
    @State private var showRecipes = false

    private let filterOptions = ["Recent", "Meals", "Favorites"]

    struct QuickFoodItem: Identifiable {
        let id = UUID()
        let name: String
        let calories: Int
        let protein: Int
        let icon: String
        let colorHex: UInt
    }

    private let quickFoods: [QuickFoodItem] = [
        QuickFoodItem(name: "Grilled Chicken Breast", calories: 165, protein: 31, icon: "fork.knife", colorHex: 0xD07C60),
        QuickFoodItem(name: "Brown Rice", calories: 215, protein: 4, icon: "circle.grid.cross.fill", colorHex: 0xE8B84B),
        QuickFoodItem(name: "Avocado", calories: 240, protein: 3, icon: "leaf.fill", colorHex: 0x4E7D3F),
        QuickFoodItem(name: "Banana", calories: 105, protein: 1, icon: "moon.fill", colorHex: 0xF7B731),
        QuickFoodItem(name: "Greek Yogurt", calories: 100, protein: 17, icon: "cup.and.saucer.fill", colorHex: 0x8CBAD9),
        QuickFoodItem(name: "Mixed Greens", calories: 15, protein: 2, icon: "camera.macro", colorHex: 0x588157)
    ]

    private let weekDays = [
        ("Mon", "28"), ("Tue", "29"), ("Wed", "30"), ("Thu", "31"),
        ("Fri", "1"), ("Sat", "2"), ("Sun", "3")
    ]

    var filteredFoods: [QuickFoodItem] {
        if searchText.isEmpty { return quickFoods }
        return quickFoods.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Search Bar (Screen 3)
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.Colors.textTertiary)
                            TextField("Search foods...", text: $searchText)
                                .font(.system(size: 15, design: .rounded))
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Theme.Colors.parchmentBorder.opacity(0.85), lineWidth: 1)
                        )

                        // Filter Pills
                        HStack(spacing: 8) {
                            ForEach(0..<filterOptions.count, id: \.self) { idx in
                                let isSelected = selectedFilter == idx
                                Button {
                                    Haptics.tap()
                                    selectedFilter = idx
                                } label: {
                                    Text(filterOptions[idx])
                                        .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                                        .foregroundStyle(isSelected ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? Theme.Colors.volt : Theme.Colors.surface, in: Capsule())
                                        .overlay(
                                            Capsule().stroke(isSelected ? Theme.Colors.volt : Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }

                        // Quick Food Items (Screen 3)
                        VStack(spacing: 8) {
                            ForEach(filteredFoods) { food in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: food.colorHex).opacity(0.18))
                                            .frame(width: 42, height: 42)
                                        Image(systemName: food.icon)
                                            .font(.system(size: 17))
                                            .foregroundStyle(Color(hex: food.colorHex))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(food.name)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                        Text("\(food.calories) cal · \(food.protein)g protein")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                    }

                                    Spacer()

                                    Button {
                                        Haptics.success()
                                        store.addMeal(name: food.name, mealType: "Lunch", calories: food.calories, protein: food.protein, carbs: 10, fat: 5)
                                        FuelFriendStore.shared.feed(mealName: food.name)
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Theme.Colors.volt)
                                            .frame(width: 34, height: 34)
                                            .background(Theme.Colors.volt.opacity(0.12), in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(12)
                                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Theme.Colors.parchmentBorder.opacity(0.75), lineWidth: 1)
                                )
                            }
                        }

                        // Week Calendar Strip (Screen 4)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Meal Plan")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)

                            HStack(spacing: 6) {
                                ForEach(0..<weekDays.count, id: \.self) { idx in
                                    let day = weekDays[idx]
                                    let isSelected = selectedDayIndex == idx
                                    Button {
                                        Haptics.tap()
                                        selectedDayIndex = idx
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text(day.0)
                                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                                .foregroundStyle(isSelected ? Theme.Colors.onVolt.opacity(0.8) : Theme.Colors.textTertiary)
                                            Text(day.1)
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(isSelected ? Theme.Colors.onVolt : Theme.Colors.textPrimary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? Theme.Colors.volt : Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(isSelected ? Theme.Colors.volt : Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Today's Meals Section (Screen 4)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Today's Meals")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textSecondary)

                            plannedMealRow(title: "Breakfast", name: "Overnight Oats", cal: 420, prot: 18, icon: "cup.and.saucer.fill", color: Theme.Colors.finchButter)
                            plannedMealRow(title: "Lunch", name: "Chicken & Rice Bowl", cal: 520, prot: 35, icon: "fork.knife", color: Theme.Colors.finchMint)
                            plannedMealRow(title: "Dinner", name: "Salmon, Quinoa, Veggies", cal: 580, prot: 40, icon: "takeoutbag.and.cup.and.straw.fill", color: Theme.Colors.finchPeach)
                            plannedMealRow(title: "Snacks", name: "Apple + Peanut Butter", cal: 210, prot: 7, icon: "leaf.fill", color: Theme.Colors.finchLavender)
                        }

                        // Action Buttons
                        VStack(spacing: 10) {
                            Button {
                                Haptics.tap()
                                showRecipes = true
                            } label: {
                                Text("Plan Tomorrow")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.Colors.onVolt)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .shadow(color: Theme.Colors.volt.opacity(0.25), radius: 8, y: 3)
                            }
                            .buttonStyle(.plain)

                            Button {
                                Haptics.tap()
                                showRecipes = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "book.fill")
                                    Text("Browse Safe Recipes")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(Theme.Colors.volt)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Theme.Colors.parchmentBorder.opacity(0.85), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.top, 12)
                    .padding(.bottom, Theme.Metrics.tabBarClearance)
                }
            }
            .navigationTitle("Meal Plan")
            .navigationDestination(isPresented: $showRecipes) {
                ZStack {
                    Theme.Colors.background.ignoresSafeArea()
                    RecipesView()
                }
                .navigationTitle("Find meals")
            }
        }
    }

    private func plannedMealRow(title: String, name: String, cal: Int, prot: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("\(cal) cal · \(prot)g protein")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(12)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.Colors.parchmentBorder.opacity(0.75), lineWidth: 1)
        )
    }
}

// MARK: - Figma Screen 5 (Goals & Habits Tab)

struct GoalsTab: View {
    @ObservedObject var store: TodayStore
    @ObservedObject private var friendStore = FuelFriendStore.shared
    var onLogFood: () -> Void = {}

    @State private var selectedScope = 0 // 0: Daily, 1: Weekly
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Scope Picker [Daily | Weekly]
                        Picker("Scope", selection: $selectedScope) {
                            Text("Daily").tag(0)
                            Text("Weekly").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 4)

                        if selectedScope == 0 {
                            dailyQuestsList
                        } else {
                            weeklyQuestsList
                        }

                        // Supportive Pip Encouragement Card
                        encouragementCard
                    }
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.top, 12)
                    .padding(.bottom, Theme.Metrics.tabBarClearance)
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                DailyPreferencesSheet(
                    waterCups: store.waterGlasses,
                    mealCount: store.meals.count,
                    calories: store.consumedCalories,
                    steps: store.todaySteps
                )
            }
        }
    }

    // MARK: Daily Quests (Screen 5)
    private var dailyQuestsList: some View {
        VStack(spacing: 12) {
            // Quest 1: Water
            questCard(
                icon: "drop.fill",
                iconColor: Color(hex: 0x38BDF8),
                title: "Drink 8 cups of water",
                progressText: "\(store.waterGlasses) / 8",
                progress: Double(store.waterGlasses) / 8.0,
                barColor: Color(hex: 0x38BDF8),
                xp: 10
            ) {
                store.setWater(store.waterGlasses + 1)
                friendStore.hydrate()
            }

            // Quest 2: Balanced meals
            questCard(
                icon: "fork.knife",
                iconColor: Theme.Colors.volt,
                title: "Eat 3 balanced meals",
                progressText: "\(min(store.meals.count, 3)) / 3",
                progress: Double(min(store.meals.count, 3)) / 3.0,
                barColor: Theme.Colors.volt,
                xp: 15
            ) {
                onLogFood()
            }

            // Quest 3: Calorie goal
            questCard(
                icon: "flame.fill",
                iconColor: Color(hex: 0xFB923C),
                title: "Stay within \(store.dynamicTargetCalories.formatted()) calories",
                progressText: "\(store.consumedCalories.formatted()) / \(store.dynamicTargetCalories.formatted())",
                progress: store.dynamicTargetCalories > 0 ? Double(store.consumedCalories) / Double(store.dynamicTargetCalories) : 0,
                barColor: Color(hex: 0xFB923C),
                xp: 20
            ) {
                onLogFood()
            }

            // Quest 4: Steps
            let steps = store.todaySteps
            questCard(
                icon: "figure.walk",
                iconColor: Color(hex: 0x8B5CF6),
                title: "Walk 8,000 steps",
                progressText: "\(steps.formatted()) / 8,000",
                progress: Double(steps) / 8000.0,
                barColor: Color(hex: 0x8B5CF6),
                xp: 15
            ) {
                Haptics.tap()
            }
        }
    }

    private func questCard(
        icon: String,
        iconColor: Color,
        title: String,
        progressText: String,
        progress: Double,
        barColor: Color,
        xp: Int,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text("+\(xp) XP")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.volt)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.Colors.volt.opacity(0.12), in: Capsule())
                    }

                    Text(progressText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.Colors.surfaceRaised)
                                .frame(height: 7)
                            Capsule()
                                .fill(barColor)
                                .frame(width: max(7, min(geo.size.width, geo.size.width * CGFloat(min(1.0, max(0.0, progress))))), height: 7)
                        }
                    }
                    .frame(height: 7)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(14)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: Weekly Quests
    private var weeklyQuestsList: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(store.mealStreak) Day Habit Streak")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Consistency grows your plant and earns rare garden decor.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
            }
            .padding(16)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1)
            )

            weeklyChallengeRow(title: "Hydration Hero: 5 days with 8+ cups", progress: "3 / 5 days", xp: 50, icon: "drop.fill", color: Color(hex: 0x38BDF8))
            weeklyChallengeRow(title: "Balanced Fuel: Log 15 meals", progress: "\(min(store.meals.count, 15)) / 15", xp: 75, icon: "fork.knife", color: Theme.Colors.volt)
            weeklyChallengeRow(title: "Active Sprout: 3 workouts this week", progress: "2 / 3", xp: 60, icon: "figure.walk", color: Color(hex: 0x8B5CF6))
            weeklyChallengeRow(title: "Weekly Reflection: Check in on gut health", progress: "1 / 1", xp: 40, icon: "heart.text.square.fill", color: Theme.Colors.finchRose)
        }
    }

    private func weeklyChallengeRow(title: String, progress: String, xp: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(progress)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Text("+\(xp) XP")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.volt)
        }
        .padding(14)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1)
        )
    }

    private var encouragementCard: some View {
        HStack(spacing: 14) {
            Image("pip_happy")
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text(store.meals.isEmpty && store.waterGlasses == 0
                     ? "No worries, we can start fresh today!"
                     : "You're doing great today!")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Every healthy choice feeds your plant and keeps \(friendStore.name) smiling.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.Colors.finchMint.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.Colors.finchMint.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Figma Screen 6 (Your Plant / Garden Tab)

struct PlantTab: View {
    @ObservedObject private var friendStore = FuelFriendStore.shared
    @State private var showPotShop = false
    @State private var showDecorShop = false
    @State private var showScrapbook = false
    @State private var showCompanions = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Stage Centerpiece (Screen 6)
                        plantStageCenterpiece

                        // Level 2 Progression Card (Screen 6)
                        levelProgressCard

                        // Action Shortcuts Grid (4 Cards)
                        actionsGrid

                        // 5 Growth Stages Showcase
                        growthStagesShowcase
                    }
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.top, 12)
                    .padding(.bottom, Theme.Metrics.tabBarClearance)
                }
            }
            .navigationTitle("Your Garden")
            .sheet(isPresented: $showPotShop) {
                PipGardenShopSheet(friendStore: friendStore, initialTab: .pots)
            }
            .sheet(isPresented: $showDecorShop) {
                PipGardenShopSheet(friendStore: friendStore, initialTab: .decor)
            }
            .sheet(isPresented: $showScrapbook) {
                PostcardScrapbookSheet(friendStore: friendStore)
            }
            .sheet(isPresented: $showCompanions) {
                FoodPalsSheet(friendStore: friendStore)
            }
        }
    }

    private var plantStageCenterpiece: some View {
        ZStack {
            // Warm cozy outdoor/windowsill background
            LinearGradient(
                colors: [Color(hex: 0xFDEED9), Color(hex: 0xF5E3C7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 270)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            // Gentle sun orb
            Circle()
                .fill(Color(hex: 0xFEE8A3).opacity(0.8))
                .frame(width: 80, height: 80)
                .offset(x: -100, y: -80)

            VStack(spacing: 0) {
                Spacer()

                // Lush potted plant & Pip
                HStack(alignment: .bottom, spacing: 16) {
                    // Pip
                    Image("pip_happy")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)

                    // Equipped Pot & Growing Plant
                    ZStack(alignment: .bottom) {
                        // Foliage growing out of the pot
                        ZStack(alignment: .bottom) {
                            // Left leaf
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(Color(hex: 0x4E7D3F))
                                .rotationEffect(.degrees(-32))
                                .offset(x: -24, y: -45)

                            // Right leaf
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(Color(hex: 0x588157))
                                .rotationEffect(.degrees(32))
                                .offset(x: 24, y: -45)

                            // Main central sprout leaf
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 46))
                                .foregroundStyle(Color(hex: 0x76A035))
                                .offset(y: -52)

                            // Flower bud / sprout dot
                            Circle()
                                .fill(Color(hex: 0xF7B731))
                                .frame(width: 12, height: 12)
                                .offset(y: -75)

                            // Equipped Pot
                            Image(friendStore.pot)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 130, height: 130)
                        }

                        // Equipped Decor item
                        if !friendStore.equippedDecor.isEmpty {
                            WindowsillDecorView(decorId: friendStore.equippedDecor)
                                .offset(x: 70, y: -10)
                        }
                    }
                }
                .offset(y: -10)

                // Windowsill shelf
                Rectangle()
                    .fill(Color(hex: 0xD8B288))
                    .frame(height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            // Speech bubble
            VStack {
                HStack {
                    Spacer()
                    Text("Our plant is growing so strong today!")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.surface, in: Capsule())
                        .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                }
                Spacer()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Theme.Colors.parchmentBorder.opacity(0.85), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, y: 4)
    }

    private var levelProgressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Level \(friendStore.level)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text("\(friendStore.xpInCurrentLevel)/100 XP")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.volt)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.surfaceRaised)
                        .frame(height: 10)
                    Capsule()
                        .fill(Theme.Colors.volt)
                        .frame(width: max(10, min(geo.size.width, geo.size.width * CGFloat(Double(friendStore.xpInCurrentLevel) / 100.0))), height: 10)
                }
            }
            .frame(height: 10)

            Text("Keep logging healthy choices to help your plant grow!")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(18)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.Colors.parchmentBorder.opacity(0.85), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
    }

    private var actionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            actionTile(title: "Change Pot", subtitle: "\(FuelFriendStore.allPots.count) Artisanal Pots", icon: "paintpalette.fill", color: Color(hex: 0xD07C60)) {
                showPotShop = true
            }
            actionTile(title: "Decor", subtitle: "\(FuelFriendStore.allDecor.count) Cozy Items", icon: "cup.and.saucer.fill", color: Theme.Colors.volt) {
                showDecorShop = true
            }
            actionTile(title: "Scrapbook", subtitle: "\(friendStore.collectedPostcards.count) Postcards", icon: "map.fill", color: Color(hex: 0x8CBAD9)) {
                showScrapbook = true
            }
            if Config.foodPalsEnabled {
                actionTile(title: "Food Pals", subtitle: "\(friendStore.availableCompanions.count) Characters", icon: "person.2.fill", color: Color(hex: 0x9D8DF1)) {
                    showCompanions = true
                }
            }
        }
    }

    private func actionTile(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var growthStagesShowcase: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Plant Growth Stages")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)

            VStack(spacing: 10) {
                stageRow(stageNum: 1, name: "Little Sprout", levelReq: "Level 1 (0–100 XP)", desc: "Baby pit cracks, first green leaf", icon: "leaf.circle.fill")
                stageRow(stageNum: 2, name: "Growing Roots", levelReq: "Level 2–3 (101–300 XP)", desc: "Sturdy stem, unlocks new pots", icon: "camera.macro")
                stageRow(stageNum: 3, name: "Little Garden", levelReq: "Level 4–6 (301–750 XP)", desc: "Blooming flowers, herb decor", icon: "fanblades.fill")
                stageRow(stageNum: 4, name: "Flourishing", levelReq: "Level 7–10 (751–1500 XP)", desc: "Miniature tree, outfits & hats", icon: "tree.fill")
                stageRow(stageNum: 5, name: "Thriving Together", levelReq: "Level 11+ (1501+ XP)", desc: "Lush conservatory of habits", icon: "house.and.flag.fill")
            }
        }
    }

    private func stageRow(stageNum: Int, name: String, levelReq: String, desc: String, icon: String) -> some View {
        let isCurrent = (friendStore.level == 1 && stageNum == 1) ||
                        ((2...3).contains(friendStore.level) && stageNum == 2) ||
                        ((4...6).contains(friendStore.level) && stageNum == 3) ||
                        ((7...10).contains(friendStore.level) && stageNum == 4) ||
                        (friendStore.level >= 11 && stageNum == 5)
        let isUnlocked = (stageNum == 1) ||
                         (stageNum == 2 && friendStore.level >= 2) ||
                         (stageNum == 3 && friendStore.level >= 4) ||
                         (stageNum == 4 && friendStore.level >= 7) ||
                         (stageNum == 5 && friendStore.level >= 11)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCurrent ? Theme.Colors.volt.opacity(0.18) : (isUnlocked ? Theme.Colors.finchMint.opacity(0.12) : Theme.Colors.surfaceRaised))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isCurrent ? Theme.Colors.volt : (isUnlocked ? Theme.Colors.finchMint : Theme.Colors.textTertiary))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    if isCurrent {
                        Text("CURRENT")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.Colors.onVolt)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.volt, in: Capsule())
                    }
                }
                Text("\(levelReq) · \(desc)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Colors.safe)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(12)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isCurrent ? Theme.Colors.volt : Theme.Colors.parchmentBorder.opacity(0.75), lineWidth: isCurrent ? 1.5 : 1)
        )
    }
}

// MARK: - Legacy Plan & Insights Tab Helpers

struct PlanTab: View {
    @State private var showRecipes = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                PlanView(onBrowseRecipes: { showRecipes = true })
            }
            .navigationTitle("Meal Plan")
            .navigationDestination(isPresented: $showRecipes) {
                ZStack {
                    Theme.Colors.background.ignoresSafeArea()
                    RecipesView()
                }
                .navigationTitle("Find meals")
            }
        }
    }
}

struct InsightsTab: View {
    var body: some View {
        NavigationStack {
            InsightsView()
        }
    }
}

// MARK: - Figma 5-Tab Custom Dock Bar

struct CustomTabBar: View {
    @Binding var selection: Int

    private struct Tab { let index: Int; let icon: String; let label: String }
    private let tabs: [Tab] = [
        Tab(index: 0, icon: "house.fill", label: "Home"),
        Tab(index: 1, icon: "fork.knife", label: "Meals"),
        Tab(index: 2, icon: "checkmark.circle.fill", label: "Goals"),
        Tab(index: 3, icon: "leaf.fill", label: "Garden"),
        Tab(index: 4, icon: "person.fill", label: "Profile"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.index) { tab in
                Button {
                    Haptics.tap()
                    selection = tab.index
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 19, weight: selection == tab.index ? .semibold : .regular))
                        Text(tab.label)
                            .font(.system(size: 10, weight: selection == tab.index ? .bold : .medium, design: .rounded))
                    }
                    .foregroundStyle(selection == tab.index ? Theme.Colors.volt : Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Theme.Colors.surface.opacity(0.88))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Theme.Colors.parchmentBorder.opacity(0.85), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 16, y: 6)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

