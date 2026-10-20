import SwiftUI

/// Meal tracker & search: your real recent foods, saved favorites and a short
/// list of common foods, plus a USDA lookup for anything you type. Barcode and
/// AI photo shortcuts, live macro bars, and FoodDetailView for portions.
struct LifesumMealLoggerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var todayStore: TodayStore

    /// Meal to log into; defaults to breakfast/lunch/dinner/snack by the clock.
    var mealCategory: String = TodayStore.displayMealType(TodayStore.mealTypeForNow())
    var isModal: Bool = false
    var onFinished: () -> Void = {}

    @State private var searchText: String = ""
    @State private var selectedTab: Int = 0 // 0: Recents, 1: Favorites, 2: Common foods
    @State private var showBarcodeScanner: Bool = false
    @State private var showAIMealCamera: Bool = false
    @State private var selectedFoodForDetail: FoodCatalogItem? = nil
    @State private var currentCategory: String = "Breakfast"
    @ObservedObject private var favorites = FavoriteFoods.shared
    @ObservedObject private var recents = RecentFoods.shared
    @State private var isLookingUp = false
    @State private var lookupError: String?
    @State private var addedFeedbackText: String? = nil

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isLoading: Bool { selectedTab == 0 && recents.isLoading && !isSearching }

    private var filteredFoods: [FoodCatalogItem] {
        if isSearching {
            // Search everything we already know; the lookup row covers the rest.
            var seen = Set<String>()
            return (recents.items + favorites.items + FoodCatalogItem.common).filter {
                ($0.name.localizedCaseInsensitiveContains(searchText) ||
                 ($0.brand?.localizedCaseInsensitiveContains(searchText) ?? false)) &&
                seen.insert($0.key).inserted
            }
        }
        switch selectedTab {
        case 1: return favorites.items
        case 2: return FoodCatalogItem.common
        default: return recents.items
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Navigation Header
                    topHeader

                    // Search Bar with Barcode Shortcut
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    ScrollView {
                        VStack(spacing: 16) {
                            // Daily Intake & Macro Goal Card
                            dailyIntakeCard

                            // Track with AI Banner
                            trackWithAIBanner

                            // Filter Segmented Icons (History, Heart, List)
                            filterTabsRow

                            if isSearching {
                                lookupRow
                            }

                            // Foods List or Skeleton
                            if isLoading {
                                SkeletonMealLogger()
                                    .padding(.top, 8)
                            } else if filteredFoods.isEmpty {
                                emptyState
                            } else {
                                foodItemsList
                            }

                            // Fresh Organic Illustration (Broccoli / Veggie / Companion)
                            mascotIllustration
                                .padding(.top, 8)
                                .padding(.bottom, isModal ? 24 : 12)

                            // When in Tab mode (embedded), render the green DONE button inline with clearance above the tab bar
                            if !isModal {
                                doneButton
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, isModal ? 110 : Theme.Metrics.tabBarClearance)
                    }
                }

                // Bottom Floating "DONE" Action Bar (Modal Sheet only)
                if isModal {
                    VStack {
                        Spacer()
                        doneBottomBar
                    }
                }

                // Quick Toast
                if let feedback = addedFeedbackText {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Colors.onVolt)
                            Text(feedback)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.onVolt)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Theme.Colors.volt, in: Capsule())
                        .shadow(color: Theme.Colors.volt.opacity(0.35), radius: 10, y: 4)
                        .padding(.bottom, 94)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedFoodForDetail) { food in
                FoodDetailView(
                    foodItem: food,
                    initialMealType: currentCategory,
                    onTracked: { meal in
                        triggerToast("Added \(meal.name)!")
                    }
                )
                .environmentObject(session)
                .environmentObject(todayStore)
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerView()
            }
            .sheet(isPresented: $showAIMealCamera) {
                AIMealLogView()
            }
            .onAppear {
                currentCategory = mealCategory
            }
            .task {
                await recents.load(session: session, today: todayStore)
                // Nothing logged yet: start on common foods instead of an empty list.
                if recents.items.isEmpty && selectedTab == 0 { selectedTab = 2 }
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodLogged)) { _ in
                Task { await recents.load(session: session, today: todayStore, force: true) }
            }
        }
    }

    // MARK: - Top Header

    private var topHeader: some View {
        HStack {
            if isModal {
                Button {
                    Haptics.tap()
                    dismiss()
                    onFinished()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.surface, in: Circle())
                        .overlay(Circle().stroke(Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1))
                }
            } else {
                Image("pip_happy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Menu {
                ForEach(["Breakfast", "Lunch", "Dinner", "Snack", "Pre-workout", "Post-workout"], id: \.self) { cat in
                    Button {
                        Haptics.tap()
                        currentCategory = cat
                    } label: {
                        HStack {
                            Text(cat)
                            if currentCategory == cat {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currentCategory)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Spacer()

            Menu {
                Button {
                    Haptics.tap()
                    showAIMealCamera = true
                } label: {
                    Label("Track with AI Photo", systemImage: "camera")
                }
                Button {
                    Haptics.tap()
                    showBarcodeScanner = true
                } label: {
                    Label("Scan Barcode", systemImage: "barcode.viewfinder")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surface, in: Circle())
                    .overlay(Circle().stroke(Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.Colors.textTertiary)

            TextField("Food, meal or brand", text: $searchText)
                .font(.system(size: 15, design: .rounded))
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { await lookUp() } }
                .onChange(of: searchText) { _ in lookupError = nil }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            Divider()
                .frame(height: 20)
                .background(Theme.Colors.parchmentBorder)

            Button {
                Haptics.tap()
                showBarcodeScanner = true
            } label: {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.Colors.volt)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.Colors.parchmentBorder.opacity(0.85), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)
    }

    // MARK: - Daily Intake Card

    private var dailyIntakeCard: some View {
        let consumed = todayStore.consumedCalories
        let target = todayStore.dynamicTargetCalories
        let ratio = target > 0 ? min(1.0, Double(consumed) / Double(target)) : 0.0

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daily intake")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()

                Text("\(consumed) / \(target) kcal")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            // Primary Total Intake Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.surfaceRaised)
                        .frame(height: 8)

                    Capsule()
                        .fill(Theme.Colors.volt)
                        .frame(width: max(8, geo.size.width * CGFloat(ratio)), height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: ratio)
                }
            }
            .frame(height: 8)

            // Three Macro Mini-Bars
            HStack(spacing: 14) {
                macroMiniBar(
                    name: "Carbs",
                    current: todayStore.consumedCarbs,
                    target: todayStore.targetCarbs,
                    color: Color(hex: 0x4EA5D9) // Blue/Lavender
                )

                macroMiniBar(
                    name: "Protein",
                    current: todayStore.consumedProtein,
                    target: todayStore.targetProtein,
                    color: Color(hex: 0xEB6B80) // Coral/Pink
                )

                macroMiniBar(
                    name: "Fat",
                    current: todayStore.consumedFat,
                    target: todayStore.targetFat,
                    color: Color(hex: 0x9D8DF1) // Violet
                )
            }
        }
        .padding(18)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.Colors.parchmentBorder.opacity(0.85), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 3)
    }

    private func macroMiniBar(name: String, current: Int, target: Int, color: Color) -> some View {
        let ratio = target > 0 ? min(1.0, Double(current) / Double(target)) : 0.0

        return VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.18))
                        .frame(height: 6)

                    Capsule()
                        .fill(color)
                        .frame(width: max(6, geo.size.width * CGFloat(ratio)), height: 6)
                }
            }
            .frame(height: 6)

            Text("\(current) / \(target) g")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Track with AI Banner

    private var trackWithAIBanner: some View {
        Button {
            Haptics.tap()
            showAIMealCamera = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.Colors.volt.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.Colors.volt)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Track with AI")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Snap meal or label for instant nutrition breakdown")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.Colors.volt.opacity(0.35), lineWidth: 1.5)
            )
            .shadow(color: Theme.Colors.volt.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter Tabs Row

    private var filterTabsRow: some View {
        HStack(spacing: 12) {
            tabIconButton(idx: 0, icon: "clock.arrow.circlepath", label: "Recent", badge: nil)
            tabIconButton(idx: 1, icon: "heart.fill", label: "Saved",
                          badge: favorites.items.isEmpty ? nil : "\(favorites.items.count)")
            tabIconButton(idx: 2, icon: "leaf.fill", label: "Common", badge: nil)
            Spacer()
        }
    }

    private func tabIconButton(idx: Int, icon: String, label: String, badge: String?) -> some View {
        let isSelected = selectedTab == idx

        return Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = idx
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Theme.Colors.onVolt.opacity(0.25) : Theme.Colors.surfaceRaised, in: Capsule())
                }
            }
            .foregroundStyle(isSelected ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Theme.Colors.volt : Theme.Colors.surface, in: Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Theme.Colors.volt : Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: isSelected ? Theme.Colors.volt.opacity(0.2) : Color.black.opacity(0.02), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Food Items List

    private var foodItemsList: some View {
        VStack(spacing: 10) {
            ForEach(filteredFoods) { food in
                foodRow(food)
            }
        }
    }

    private func foodRow(_ food: FoodCatalogItem) -> some View {
        let hasAllergen = !food.triggerHits(session.allergensForAI).isEmpty

        return Button {
            Haptics.tap()
            selectedFoodForDetail = food
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(hasAllergen ? Theme.Colors.danger.opacity(0.14) : Theme.Colors.volt.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: food.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(hasAllergen ? Theme.Colors.danger : Theme.Colors.volt)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(food.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)

                        if hasAllergen {
                            Text("ALERT")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.Colors.onVolt)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.danger, in: Capsule())
                        }
                    }

                    Text("\(food.baseCalories) kcal · \(Int(food.baseProtein.rounded()))g prot · \(Int(food.baseCarbs.rounded()))g carbs")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                // 1-Tap Quick Add Button
                Button {
                    quickAdd(food)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Colors.volt)
                        .frame(width: 36, height: 36)
                        .background(Theme.Colors.volt.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func quickAdd(_ food: FoodCatalogItem) {
        Haptics.success()
        todayStore.addMeal(
            name: food.name,
            mealType: currentCategory,
            calories: food.baseCalories,
            protein: Int(food.baseProtein.rounded()),
            carbs: Int(food.baseCarbs.rounded()),
            fat: Int(food.baseFat.rounded())
        )
        FuelFriendStore.shared.feed(mealName: food.name)
        triggerToast("Added \(food.name) to \(currentCategory)!")
    }

    private func triggerToast(_ msg: String) {
        withAnimation {
            addedFeedbackText = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                addedFeedbackText = nil
            }
        }
    }

    // MARK: - USDA lookup

    /// "Look up <query>": the AI identifies the food, USDA supplies every number.
    private var lookupRow: some View {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return Button {
            Task { await lookUp() }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.volt.opacity(0.14))
                        .frame(width: 44, height: 44)
                    if isLookingUp {
                        ProgressView().tint(Theme.Colors.volt)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.Colors.volt)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(isLookingUp ? "Looking up \u{201C}\(query)\u{201D}..." : "Look up \u{201C}\(query)\u{201D}")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(lookupError ?? "Nutrition from the USDA database, checked against your triggers")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(lookupError == nil ? Theme.Colors.textSecondary : Theme.Colors.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(14)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.Colors.volt.opacity(0.35), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(isLookingUp)
    }

    @MainActor
    private func lookUp() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !isLookingUp else { return }
        isLookingUp = true
        lookupError = nil
        defer { isLookingUp = false }
        do {
            let food = try await FoodLookup.lookup(query, triggers: session.allergensForAI)
            Haptics.tap()
            selectedFoodForDetail = food
        } catch let e as FoodLookup.LookupError {
            lookupError = e.errorDescription
        } catch {
            lookupError = "Couldn't look that up right now. Check your connection and try again."
        }
    }

    // MARK: - Empty State

    private var emptyTitle: String {
        if isSearching { return "Not in your foods yet" }
        switch selectedTab {
        case 1: return "No saved foods yet"
        default: return "Nothing logged yet"
        }
    }

    private var emptyDetail: String {
        if isSearching { return "Tap the lookup above to get it from the USDA database." }
        switch selectedTab {
        case 1: return "Tap the heart on any food to save it here."
        default: return "Foods you log show up here so you can add them again in one tap."
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(Theme.Colors.textTertiary)
                .padding(.top, 24)

            Text(emptyTitle)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(emptyDetail)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Mascot Illustration (Broccoli / Veggie / Companion)

    private var mascotIllustration: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.Colors.volt.opacity(0.18), Theme.Colors.volt.opacity(0.0)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 90
                        )
                    )
                    .frame(width: 160, height: 160)

                Image("pip_happy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
            }

            Text("Pip is ready to nourish with you")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - "DONE" Action Button

    private var doneButton: some View {
        Button {
            Haptics.success()
            if isModal {
                dismiss()
            }
            onFinished()
        } label: {
            Text("DONE")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Colors.onVolt)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.Colors.volt)
                        .shadow(color: Theme.Colors.volt.opacity(0.35), radius: 12, y: 4)
                )
        }
        .buttonStyle(.plain)
    }

    private var doneBottomBar: some View {
        doneButton
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
    }
}
