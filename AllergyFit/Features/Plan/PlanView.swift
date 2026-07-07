import SwiftUI

/// AI meal plan — day strip, meal cards, One-Tap Swap, grocery list.
struct PlanView: View {
    @State private var meals = MockData.planMeals
    @State private var selectedDay = 2
    @State private var showGroceries = UserDefaults.standard.bool(forKey: "showGroceries")
    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Metrics.spacing) {
                dayStrip
                planSummary
                ForEach(meals) { meal in
                    PlanMealCard(meal: meal) { swap(meal) }
                }
                groceryButton
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showGroceries) { GroceryListView() }
    }

    private func swap(_ meal: DemoMeal) {
        guard let idx = meals.firstIndex(of: meal),
              let alts = MockData.swapAlternatives[meal.name],
              let alt = alts.randomElement() else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            meals[idx].name = alt
            meals[idx].calories += Int.random(in: -30...30)
            meals[idx].protein += Int.random(in: -4...4)
        }
    }

    private var dayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days.indices, id: \.self) { i in
                    Button {
                        selectedDay = i
                    } label: {
                        VStack(spacing: 4) {
                            Text(days[i])
                                .font(Theme.Fonts.caption)
                            Text("\(i + 7)")
                                .font(Theme.Fonts.stat(18))
                            if i == selectedDay {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                            }
                        }
                        .frame(width: 56, height: 72)
                        .background(i == selectedDay ? Theme.Colors.volt : Theme.Colors.surface)
                        .foregroundStyle(i == selectedDay ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    private var planSummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Training day plan")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("2,140 kcal · 131g protein · all safe")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.title3)
                .foregroundStyle(Theme.Colors.safe)
        }
        .card()
    }

    private var groceryButton: some View {
        Button {
            showGroceries = true
        } label: {
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundStyle(Theme.Colors.onVolt)
                Text("Grocery list · \(MockData.groceryList.count) items")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.onVolt)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Theme.Colors.volt)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.top, 8)
    }
}

struct PlanMealCard: View {
    let meal: DemoMeal
    let onSwap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(meal.mealType, systemImage: meal.icon)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.volt)
                Spacer()
                Image(systemName: "checkmark.shield.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.safe)
            }
            Text(meal.name)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                macro("\(meal.calories)", "kcal", Theme.Colors.textPrimary)
                macro("\(meal.protein)g", "protein", Theme.Colors.protein)
                macro("\(meal.carbs)g", "carbs", Theme.Colors.carbs)
                macro("\(meal.fat)g", "fat", Theme.Colors.fat)
                Spacer()
                Button(action: onSwap) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Swap")
                    }
                    .font(Theme.Fonts.caption)
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(Theme.Colors.volt)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.volt.opacity(0.12), in: Capsule())
                }
            }
        }
        .card()
    }

    private func macro(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(Theme.Fonts.stat(15))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }
}

struct GroceryListView: View {
    @State private var items = MockData.groceryList
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(Theme.Colors.safe)
                            Text("Every item pre-checked against your allergen profile")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Spacer()
                        }
                        .card()

                        ForEach($items) { $item in
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) { item.checked.toggle() }
                            } label: {
                                HStack {
                                    Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(item.checked ? Theme.Colors.volt : Theme.Colors.textTertiary)
                                    Text(item.name)
                                        .font(Theme.Fonts.headline)
                                        .foregroundStyle(item.checked ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                                        .strikethrough(item.checked, color: Theme.Colors.textTertiary)
                                    Spacer()
                                    Text(item.quantity)
                                        .font(Theme.Fonts.caption)
                                        .foregroundStyle(Theme.Colors.textSecondary)
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
