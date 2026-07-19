import SwiftUI

/// Hands-free cook mode — one step per screen, big and glanceable from across
/// the kitchen. Progress dots, Next/Back, and a peek at the ingredient list.
/// Mirrors the Mealime-style flow from the reference set.
struct CookModeView: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe

    @State private var step = 0
    @State private var showIngredients = false

    private var steps: [String] { recipe.steps }
    private var isLast: Bool { step >= steps.count - 1 }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Top bar: close + recipe title
                HStack {
                    Text(recipe.title)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Button { Haptics.tap(); dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(width: 34, height: 34)
                            .background(Theme.Colors.surface, in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // The step — the whole point, oversized
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Step \(step + 1) of \(steps.count)")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.volt)
                        Text("\(step + 1)")
                            .font(Theme.Fonts.stat(64))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(steps.indices.contains(step) ? steps[step] : "")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }

                // Progress dots
                HStack(spacing: 6) {
                    ForEach(steps.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? Theme.Colors.volt : Theme.Colors.surfaceRaised)
                            .frame(width: i == step ? 22 : 7, height: 7)
                            .animation(.spring(response: 0.3), value: step)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)

                // Controls: ingredients peek · Back · Next/Done
                HStack(spacing: 12) {
                    Button { showIngredients = true } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(width: 54, height: 54)
                            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    if step > 0 {
                        Button { Haptics.tap(); withAnimation { step -= 1 } } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .frame(width: 54, height: 54)
                                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    Button {
                        if isLast {
                            Haptics.success(); dismiss()
                        } else {
                            Haptics.tap(); withAnimation { step += 1 }
                        }
                    } label: {
                        Text(isLast ? "Done cooking" : "Next")
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.onVolt)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .pressable()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showIngredients) {
            ingredientSheet
        }
    }

    private var ingredientSheet: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(recipe.ingredients, id: \.self) { ing in
                            HStack(alignment: .top, spacing: 10) {
                                Circle().fill(Theme.Colors.volt).frame(width: 6, height: 6).padding(.top, 8)
                                Text(ing)
                                    .font(Theme.Fonts.body)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
            }
            .navigationTitle("Ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
        }
    }
}
