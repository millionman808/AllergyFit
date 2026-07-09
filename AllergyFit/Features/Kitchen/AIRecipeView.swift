import SwiftUI

/// Volt writes you an allergen-safe recipe from a request or your ingredients.
struct AIRecipeView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var planStore: PlanStore
    @Environment(\.dismiss) private var dismiss
    var onSave: (Recipe) -> Void = { _ in }

    @State private var request = ""
    @State private var isGenerating = false
    @State private var recipe: GeneratedRecipe?
    @State private var errorMessage: String?
    @State private var loadingIndex = 0
    @State private var savedRecipe: Recipe?
    @State private var toast: String?

    private let loadingMessages = [
        "Checking your allergen profile…",
        "Picking safe ingredients…",
        "Writing the steps…",
        "Estimating the macros…",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                        if let recipe {
                            recipeCard(recipe)
                        } else if isGenerating {
                            loadingSection
                        } else {
                            inputSection
                        }
                        if let errorMessage {
                            Text(errorMessage).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.danger)
                        }
                    }
                    .padding(Theme.Metrics.screenPadding)
                }
                if let toast {
                    VStack { Spacer()
                        Label(toast, systemImage: "checkmark.circle.fill")
                            .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.onVolt)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(Theme.Colors.volt, in: Capsule()).padding(.bottom, 24)
                    }.transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Recipe from Volt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }.foregroundStyle(Theme.Colors.textSecondary)
                }
                if recipe != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { reset() } label: { Image(systemName: "arrow.clockwise") }
                            .foregroundStyle(Theme.Colors.volt)
                    }
                }
            }
        }
    }

    // MARK: Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill").font(.title3).foregroundStyle(Theme.Colors.volt)
                Text("What are you in the mood for?")
                    .font(Theme.Fonts.title).foregroundStyle(Theme.Colors.textPrimary)
            }
            Text("Describe a craving, or list what's in your fridge. Volt writes a recipe that's safe for your triggers — \(AllergenCatalog.names(for: session.allergenSlugs).joined(separator: ", ")).")
                .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)

            ZStack(alignment: .topLeading) {
                if request.isEmpty {
                    Text("e.g. high-protein dinner with chicken and rice\ne.g. a cozy dairy-free soup\ne.g. what can I make with eggs and spinach?")
                        .font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textTertiary).padding(16)
                }
                TextEditor(text: $request)
                    .font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                    .scrollContentBackground(.hidden).padding(10).frame(minHeight: 120)
            }
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button { generate() } label: {
                Label("Generate recipe", systemImage: "sparkles")
                    .font(Theme.Fonts.headline).frame(maxWidth: .infinity).frame(height: 54)
                    .background(Theme.Colors.volt).foregroundStyle(Theme.Colors.onVolt)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Button {
                request = ""
                generate()
            } label: {
                Text("Or surprise me")
                    .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.volt)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(Theme.Colors.volt)
            Text(loadingMessages[loadingIndex])
                .font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textSecondary)
                .id(loadingIndex).transition(.opacity)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 90)
        .onAppear { advanceLoading() }
    }

    private func advanceLoading() {
        guard isGenerating else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard isGenerating else { return }
            withAnimation { loadingIndex = (loadingIndex + 1) % loadingMessages.count }
            advanceLoading()
        }
    }

    // MARK: Recipe card

    @ViewBuilder
    private func recipeCard(_ r: GeneratedRecipe) -> some View {
        // Header
        VStack(alignment: .leading, spacing: 8) {
            Text(r.title).font(Theme.Fonts.title).foregroundStyle(Theme.Colors.textPrimary)
            Text(r.description).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                metaChip("clock", "\(r.totalTimeMinutes) min")
                metaChip("person.2", "\(r.servings) servings")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()

        // Safe note
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill").foregroundStyle(Theme.Colors.safe)
            Text(r.safeNote).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()

        // Nutrition
        VStack(alignment: .leading, spacing: 8) {
            Text("Per serving · estimated").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textTertiary)
            HStack(spacing: 14) {
                macro("\(r.nutritionPerServing.calories)", "kcal", Theme.Colors.textPrimary)
                macro("\(r.nutritionPerServing.protein)g", "protein", Theme.Colors.protein)
                macro("\(r.nutritionPerServing.carbs)g", "carbs", Theme.Colors.carbs)
                macro("\(r.nutritionPerServing.fat)g", "fat", Theme.Colors.fat)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()

        // Ingredients
        VStack(alignment: .leading, spacing: 8) {
            Text("Ingredients").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
            ForEach(r.ingredients, id: \.self) { ing in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(Theme.Colors.volt).frame(width: 5, height: 5).padding(.top, 7)
                    (Text(ing.amount).foregroundColor(Theme.Colors.textPrimary).bold()
                     + Text(" \(ing.name)").foregroundColor(Theme.Colors.textSecondary))
                        .font(Theme.Fonts.body)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()

        // Steps
        VStack(alignment: .leading, spacing: 10) {
            Text("Steps").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
            ForEach(Array(r.steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(idx + 1)").font(Theme.Fonts.stat(14)).foregroundStyle(Theme.Colors.onVolt)
                        .frame(width: 24, height: 24).background(Theme.Colors.volt, in: Circle())
                    Text(step).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()

        // Actions
        HStack(spacing: 10) {
            Button {
                let saved = r.asRecipe()
                savedRecipe = saved
                onSave(saved)
                showToast("Saved to your recipes")
            } label: {
                Label("Save", systemImage: "heart.fill")
                    .font(Theme.Fonts.headline).frame(maxWidth: .infinity).frame(height: 52)
                    .background(Theme.Colors.volt).foregroundStyle(Theme.Colors.onVolt)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Menu {
                Section("Add to plan") {
                    ForEach(0..<7, id: \.self) { day in
                        Button(PlanStore.dayNames[day]) {
                            planStore.add(savedRecipe ?? r.asRecipe(), to: day)
                            showToast("Added to \(PlanStore.dayNames[day])")
                        }
                    }
                }
            } label: {
                Image(systemName: "calendar.badge.plus").font(.title3)
                    .frame(width: 52, height: 52)
                    .background(Theme.Colors.surface).foregroundStyle(Theme.Colors.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }

        Text("Nutrition is an AI estimate. Always verify ingredient labels for your allergens.")
            .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textTertiary)
    }

    private func metaChip(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.volt)
    }
    private func macro(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 2) { Text(v).font(Theme.Fonts.stat(17)).foregroundStyle(c)
            Text(l).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(Theme.Colors.textTertiary) }
            .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private func generate() {
        isGenerating = true
        errorMessage = nil
        Task {
            defer { isGenerating = false }
            do {
                let goal = session.isDemo ? "build" : ""
                recipe = try await RecipeGenService.generate(
                    request: request, allergens: session.allergenSlugs, dietary: [], goal: goal)
            } catch {
                errorMessage = "Couldn't generate: \(error.localizedDescription)"
            }
        }
    }

    private func reset() {
        withAnimation { recipe = nil; savedRecipe = nil; errorMessage = nil }
    }
    private func showToast(_ m: String) {
        withAnimation { toast = m }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation { toast = nil } }
    }
}
