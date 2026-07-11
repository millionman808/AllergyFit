import SwiftUI

/// "Today" — functional daily dashboard backed by TodayStore.
struct DashboardView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var store = TodayStore()
    @StateObject private var trends = TrendsStore()
    @State private var showQuickAdd = false
    @State private var showTrends = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Metrics.spacing) {
                        safetyBanner
                        calorieCard
                        macroRow
                        TrendsCard(store: trends) { showTrends = true }
                        streakCard
                        mealsSection
                        waterCard
                    }
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.bottom, 24)
                }
                .refreshable { await store.refresh() }
            }
            .navigationTitle("Today")
            .onAppear {
                store.configure(session: session)
                trends.configure(session: session, targetCalories: store.targetCalories)
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddMealView { name, type, cal, p, c, f in
                    store.addMeal(name: name, mealType: type, calories: cal, protein: p, carbs: c, fat: f)
                }
            }
            .sheet(isPresented: $showTrends) {
                TrendsView(store: trends)
            }
        }
    }

    private var safetyBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title3)
                .foregroundStyle(Theme.Colors.safe)
            VStack(alignment: .leading, spacing: 2) {
                Text("Allergy-safe day")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("0 flagged ingredients in \(store.meals.count) meal\(store.meals.count == 1 ? "" : "s")")
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
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(store.consumedCalories.formatted())")
                    .font(Theme.Fonts.stat(56))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .contentTransition(.numericText())
                Text("/ \(store.targetCalories.formatted())")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            Text("calories · \(store.remainingCalories.formatted()) remaining")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Colors.surfaceRaised)
                    Capsule()
                        .fill(progress > 1 ? Theme.Colors.caution : Theme.Colors.volt)
                        .frame(width: geo.size.width * min(progress, 1))
                        .animation(.spring(response: 0.4), value: progress)
                }
            }
            .frame(height: 10)
        }
        .frame(maxWidth: .infinity)
        .card()
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
                .foregroundStyle(Theme.Colors.volt)
            VStack(alignment: .leading, spacing: 2) {
                Text("Reaction-free streak")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(store.hasReactionHistory ? "Since your last symptom check-in" : "No reactions logged — keep it up")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(store.reactionFreeStreak)")
                    .font(Theme.Fonts.stat(36))
                    .foregroundStyle(Theme.Colors.volt)
                    .contentTransition(.numericText())
                Text(store.reactionFreeStreak == 1 ? "day" : "days")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .card()
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
        HStack {
            Image(systemName: "drop.fill")
                .font(.title3)
                .foregroundStyle(Theme.Colors.protein)
            Text("Water")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<store.waterGoal, id: \.self) { i in
                    Button {
                        // Tap a filled glass to un-fill down to it; tap empty to fill up to it.
                        store.setWater(i < store.waterGlasses ? i : i + 1)
                    } label: {
                        Circle()
                            .fill(i < store.waterGlasses ? Theme.Colors.protein : Theme.Colors.surfaceRaised)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            Text("\(store.waterGlasses)/\(store.waterGoal)")
                .font(Theme.Fonts.stat(16))
                .foregroundStyle(Theme.Colors.textSecondary)
                .contentTransition(.numericText())
        }
        .card()
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
            Image(systemName: "checkmark.shield.fill")
                .font(.caption)
                .foregroundStyle(Theme.Colors.safe)
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
