import SwiftUI

/// Quick-add sheet: log a meal with macros in seconds.
struct QuickAddMealView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, String, Int, Int, Int, Int) -> Void

    @State private var name = ""
    @State private var mealType = "Snack"
    @State private var calories = 400
    @State private var protein = 25
    @State private var carbs = 40
    @State private var fat = 12

    private let types = ["Breakfast", "Lunch", "Dinner", "Snack", "Pre-workout", "Post-workout"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Metrics.spacing) {
                        TextField("What did you eat?", text: $name)
                            .font(Theme.Fonts.body)
                            .padding(14)
                            .background(Theme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(Theme.Colors.textPrimary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(types, id: \.self) { t in
                                    Button {
                                        mealType = t
                                    } label: {
                                        Text(t)
                                            .font(Theme.Fonts.caption)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(mealType == t ? Theme.Colors.volt : Theme.Colors.surface)
                                            .foregroundStyle(mealType == t ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        macroStepper("Calories", value: $calories, step: 25, unit: "kcal", color: Theme.Colors.volt)
                        macroStepper("Protein", value: $protein, step: 5, unit: "g", color: Theme.Colors.protein)
                        macroStepper("Carbs", value: $carbs, step: 5, unit: "g", color: Theme.Colors.carbs)
                        macroStepper("Fat", value: $fat, step: 2, unit: "g", color: Theme.Colors.fat)

                        Button {
                            onSave(name.isEmpty ? "Quick meal" : name, mealType, calories, protein, carbs, fat)
                            dismiss()
                        } label: {
                            Text("Log Meal")
                                .font(Theme.Fonts.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Theme.Colors.volt)
                                .foregroundStyle(Theme.Colors.onVolt)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .padding(.top, 4)
                    }
                    .padding(Theme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Quick add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private func macroStepper(_ label: String, value: Binding<Int>, step: Int, unit: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Button {
                value.wrappedValue = max(0, value.wrappedValue - step)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.surfaceRaised, Theme.Colors.textSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value.wrappedValue)")
                    .font(Theme.Fonts.stat(22))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .frame(minWidth: 56)
                Text(unit)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            Button {
                value.wrappedValue += step
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(color.opacity(0.25), color)
            }
        }
        .card()
    }
}
