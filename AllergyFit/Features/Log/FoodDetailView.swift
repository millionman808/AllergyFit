import SwiftUI

/// Food detail & nutrition breakdown: portion picker, macro rings, a
/// trigger check and labels worked out from the actual numbers, 1-tap tracking.
struct FoodDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var todayStore: TodayStore

    let foodItem: FoodCatalogItem
    var initialMealType: String = "Breakfast"
    var onTracked: ((TodayMeal) -> Void)? = nil

    @State private var quantity: Double = 1.0
    @State private var selectedUnitIndex: Int = 0
    @State private var selectedMealType: String = "Breakfast"
    @State private var isFavorite: Bool = false
    @State private var ringAnimationProgress: CGFloat = 0.0
    @State private var isTracking: Bool = false
    @State private var showAddedToast: Bool = false

    var units: [FoodCatalogItem.ServingUnit] { foodItem.servingUnits }

    var currentUnit: FoodCatalogItem.ServingUnit {
        guard units.indices.contains(selectedUnitIndex) else {
            return FoodCatalogItem.ServingUnit(name: "Serving", gramWeight: 100, multiplier: 1.0)
        }
        return units[selectedUnitIndex]
    }

    var scaleFactor: Double {
        quantity * currentUnit.multiplier
    }

    var dynamicCalories: Int {
        max(1, Int((Double(foodItem.baseCalories) * scaleFactor).rounded()))
    }

    var dynamicProtein: Double {
        Double(foodItem.baseProtein) * scaleFactor
    }

    var dynamicCarbs: Double {
        Double(foodItem.baseCarbs) * scaleFactor
    }

    var dynamicFat: Double {
        Double(foodItem.baseFat) * scaleFactor
    }

    // Percentage of total macro weight
    var totalMacroGrams: Double {
        max(0.1, dynamicProtein + dynamicCarbs + dynamicFat)
    }

    var carbsPercentage: Int {
        Int(((dynamicCarbs / totalMacroGrams) * 100).rounded())
    }

    var proteinPercentage: Int {
        Int(((dynamicProtein / totalMacroGrams) * 100).rounded())
    }

    var fatPercentage: Int {
        Int(((dynamicFat / totalMacroGrams) * 100).rounded())
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Navigation Bar
                navBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title & Brand
                        titleHeader

                        // Portion & Meal Pickers
                        portionSelectors

                        // Calories Display
                        caloriesRow

                        // Macro Donut Rings
                        macroRingsSection

                        // Food Rating & Allergy Assessment
                        foodRatingSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 120) // Clearance for bottom button
                }
            }

            // Floating Bottom Track Button
            VStack {
                Spacer()
                trackFloatingButton
            }

            // Success Toast
            if showAddedToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Colors.onVolt)
                        Text("Logged \(foodItem.name) to \(selectedMealType)!")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.onVolt)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.volt, in: Capsule())
                    .shadow(color: Theme.Colors.volt.opacity(0.35), radius: 10, y: 4)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            selectedMealType = initialMealType
            isFavorite = FavoriteFoods.shared.contains(foodItem)
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.15)) {
                ringAnimationProgress = 1.0
            }
        }
    }

    // MARK: - Navigation Bar

    private var navBar: some View {
        HStack {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surface, in: Circle())
                    .overlay(Circle().stroke(Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1))
            }

            Spacer()

            Button {
                Haptics.success()
                FavoriteFoods.shared.toggle(foodItem)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isFavorite = FavoriteFoods.shared.contains(foodItem)
                }
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isFavorite ? Theme.Colors.danger : Theme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surface, in: Circle())
                    .overlay(Circle().stroke(Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1))
                    .scaleEffect(isFavorite ? 1.15 : 1.0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Title Header

    private var titleHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(foodItem.name)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let brand = foodItem.brand, !brand.isEmpty {
                Text("(\(brand))")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    // MARK: - Portion & Meal Selectors

    private var portionSelectors: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Quantity Picker
                HStack(spacing: 6) {
                    TextField("1", value: $quantity, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 54, height: 46)
                        .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Serving Unit Menu
                Menu {
                    ForEach(units.indices, id: \.self) { idx in
                        Button {
                            Haptics.tap()
                            selectedUnitIndex = idx
                        } label: {
                            Text(units[idx].name)
                        }
                    }
                } label: {
                    HStack {
                        Text(currentUnit.name)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            // Meal Selector Dropdown
            Menu {
                ForEach(["Breakfast", "Lunch", "Dinner", "Snack", "Pre-workout", "Post-workout"], id: \.self) { meal in
                    Button {
                        Haptics.tap()
                        selectedMealType = meal
                    } label: {
                        Text(meal)
                    }
                }
            } label: {
                HStack {
                    Text(selectedMealType)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Calories Display

    private var caloriesRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.Colors.finchPeach)

            Text("\(dynamicCalories)")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("kcal")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Macro Donut Rings

    private var macroRingsSection: some View {
        HStack(spacing: 0) {
            // Carbs Donut
            macroDonut(
                title: "Carbs",
                grams: dynamicCarbs,
                percentage: carbsPercentage,
                color: Color(hex: 0x4EA5D9) // Blue/Purple
            )

            Spacer()

            // Protein Donut
            macroDonut(
                title: "Protein",
                grams: dynamicProtein,
                percentage: proteinPercentage,
                color: Color(hex: 0xEB6B80) // Coral/Pink
            )

            Spacer()

            // Fat Donut
            macroDonut(
                title: "Fat",
                grams: dynamicFat,
                percentage: fatPercentage,
                color: Color(hex: 0x9D8DF1) // Lavender/Violet
            )
        }
        .padding(20)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.Colors.parchmentBorder.opacity(0.85), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 3)
    }

    private func macroDonut(title: String, grams: Double, percentage: Int, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                // Background track
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: 6)

                // Foreground ring
                Circle()
                    .trim(from: 0, to: min(1.0, CGFloat(percentage) / 100.0 * ringAnimationProgress))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(percentage)%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .frame(width: 66, height: 66)

            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(String(format: "%.1f g", grams))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Food Rating & Allergy Assessment

    private var foodRatingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("FOOD RATING & SAFETY")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Spacer()

                Button {
                    Haptics.tap()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                // Score Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(ratingFaceColor.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: ratingFaceIcon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(ratingFaceColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("\(dynamicCalories)")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("kcal / portion")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }

                        Text(foodItem.safetySummary(allergens: triggers))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(ratingFaceColor)
                        Text("Nutrition: \(foodItem.source)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }

                Divider()
                    .background(Theme.Colors.parchmentBorder.opacity(0.7))

                // Pros & Cons Grid
                VStack(alignment: .leading, spacing: 10) {
                    // Positives
                    ForEach(foodItem.positiveTraits(scale: scaleFactor), id: \.self) { trait in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.Colors.safe)
                            Text(trait)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                    }

                    // Alerts / Negatives
                    ForEach(foodItem.cautionTraits(allergens: triggers, scale: scaleFactor), id: \.self) { caution in
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.Colors.danger)
                            Text(caution)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.danger)
                        }
                    }
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
    }

    /// Standard triggers plus anything the user typed themselves.
    private var triggers: [String] { session.allergensForAI }

    private var ratingFaceIcon: String {
        if !foodItem.triggerHits(triggers).isEmpty { return "exclamationmark.triangle.fill" }
        if !foodItem.allergensKnown { return "questionmark.circle.fill" }
        if !foodItem.cautionTraits(allergens: triggers, scale: scaleFactor).isEmpty { return "face.dashed" }
        return "face.smiling.fill"
    }

    private var ratingFaceColor: Color {
        if !foodItem.triggerHits(triggers).isEmpty { return Theme.Colors.danger }
        if !foodItem.allergensKnown { return Theme.Colors.caution }
        return Theme.Colors.safe
    }

    // MARK: - Floating Track Button

    private var trackFloatingButton: some View {
        Button {
            executeTrack()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 17, weight: .bold))

                Text("TRACK · \(dynamicCalories) kcal")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(Theme.Colors.onVolt)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.Colors.volt)
                    .shadow(color: Theme.Colors.volt.opacity(0.38), radius: 14, y: 5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
    }

    private func executeTrack() {
        guard !isTracking else { return }
        isTracking = true
        Haptics.success()

        let meal = TodayMeal(
            id: UUID(),
            name: foodItem.name,
            mealType: selectedMealType,
            time: DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short),
            calories: dynamicCalories,
            protein: Int(dynamicProtein.rounded()),
            carbs: Int(dynamicCarbs.rounded()),
            fat: Int(dynamicFat.rounded()),
            icon: foodItem.icon
        )

        todayStore.addMeal(
            name: meal.name,
            mealType: meal.mealType,
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fat: meal.fat
        )

        // Feed the companion Pip
        FuelFriendStore.shared.feed(mealName: meal.name)

        onTracked?(meal)

        withAnimation {
            showAddedToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }
}
