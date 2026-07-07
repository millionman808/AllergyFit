import SwiftUI
import Supabase

/// AI meal logger: describe what you ate → Claude parses → USDA nutrition
/// → allergens + confidence → editable ingredients → save to the daily log.
struct AIMealLogView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    enum Phase: Equatable {
        case input, loading, clarifying, result, saved
    }

    @State private var phase: Phase = .input
    @State private var mealText = ""
    @State private var conversation: [AIMealService.ChatMessage] = []
    @State private var questions: [String] = []
    @State private var answerText = ""
    @State private var meal: AnalyzedMeal?
    @State private var errorMessage: String?
    @State private var loadingIndex = 0
    @State private var editingItem: AnalyzedItem?
    @State private var swappingItemId: Int?

    // TODO: pull from the signed-in user's profile
    private let allergenSlugs = ["peanut", "dairy", "sesame"]

    private let loadingMessages = [
        "Understanding your meal…",
        "Identifying ingredients…",
        "Looking up nutrition…",
        "Checking allergens…",
        "Calculating macros…",
    ]

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                    switch phase {
                    case .input: inputSection
                    case .loading: loadingSection
                    case .clarifying: claritySection
                    case .result, .saved: if let meal { resultSection(meal) }
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.danger)
                    }
                }
                .padding(Theme.Metrics.screenPadding)
            }
        }
        .navigationTitle("Log Meal")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingItem) { item in
            EditIngredientSheet(item: item) { updated in
                applyEdit(updated, original: item)
            }
        }
        .onAppear {
            if UserDefaults.standard.bool(forKey: "mockMealResult"), meal == nil {
                meal = .mock
                phase = .result
            }
        }
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
            Text("What did you eat?")
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.textPrimary)

            ZStack(alignment: .topLeading) {
                if mealText.isEmpty {
                    Text("Examples:\n· 2 scrambled eggs, toast and butter\n· Chicken Caesar salad\n· Starbucks Grande Caramel Macchiato\n· Homemade beef tacos with cheese")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(16)
                }
                TextEditor(text: $mealText)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 160)
            }
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                startAnalysis()
            } label: {
                Label("Analyze Meal", systemImage: "sparkles")
                    .font(Theme.Fonts.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(mealText.isEmpty ? Theme.Colors.surfaceRaised : Theme.Colors.volt)
                    .foregroundStyle(mealText.isEmpty ? Theme.Colors.textTertiary : Theme.Colors.onVolt)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(mealText.isEmpty)

            Text("Nutrition comes from the USDA food database — the AI never guesses numbers. If something important is missing, it will ask before calculating.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.Colors.volt)
            Text(loadingMessages[loadingIndex])
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .id(loadingIndex)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .onAppear { advanceLoadingMessage() }
    }

    private func advanceLoadingMessage() {
        guard phase == .loading else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            guard phase == .loading else { return }
            withAnimation { loadingIndex = (loadingIndex + 1) % loadingMessages.count }
            advanceLoadingMessage()
        }
    }

    // MARK: - Clarifying questions

    private var claritySection: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
            Label("Quick question\(questions.count > 1 ? "s" : "")", systemImage: "questionmark.bubble.fill")
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.volt)

            ForEach(questions, id: \.self) { q in
                Text(q)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            }

            TextField("Your answer…", text: $answerText, axis: .vertical)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(14)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                submitAnswer()
            } label: {
                Text("Continue")
                    .font(Theme.Fonts.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(answerText.isEmpty ? Theme.Colors.surfaceRaised : Theme.Colors.volt)
                    .foregroundStyle(answerText.isEmpty ? Theme.Colors.textTertiary : Theme.Colors.onVolt)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(answerText.isEmpty)
        }
    }

    // MARK: - Result

    @ViewBuilder
    private func resultSection(_ meal: AnalyzedMeal) -> some View {
        // Summary card
        VStack(spacing: 8) {
            Text(meal.name)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text("\(Int(meal.totals.calories))")
                .font(Theme.Fonts.stat(56))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("calories")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
            HStack(spacing: 14) {
                macroBar("Protein", meal.totals.protein, Theme.Colors.protein, totals: meal.totals)
                macroBar("Carbs", meal.totals.carbs, Theme.Colors.carbs, totals: meal.totals)
                macroBar("Fat", meal.totals.fat, Theme.Colors.fat, totals: meal.totals)
            }
            .padding(.top, 6)
            HStack(spacing: 16) {
                secondaryStat("Fiber", meal.totals.fiber, "g")
                secondaryStat("Sugar", meal.totals.sugar, "g")
                secondaryStat("Sodium", meal.totals.sodium, "mg")
            }
        }
        .frame(maxWidth: .infinity)
        .card()

        confidenceCard(meal.confidence)
        allergenCard(meal.allergens)

        // Ingredients
        Text("Ingredients")
            .font(Theme.Fonts.title)
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.top, 4)

        ForEach(meal.items) { item in
            ingredientRow(item)
        }

        if !meal.suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Ideas", systemImage: "lightbulb.fill")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.volt)
                ForEach(meal.suggestions, id: \.self) { s in
                    Text("· \(s)")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }

        if phase == .saved {
            Label("Added to today's log", systemImage: "checkmark.circle.fill")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.safe)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        } else {
            Button {
                Task { await saveMeal(meal) }
            } label: {
                Text("Save Meal")
                    .font(Theme.Fonts.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.Colors.volt)
                    .foregroundStyle(Theme.Colors.onVolt)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Button {
                reset()
            } label: {
                Text("Start over")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func macroBar(_ label: String, _ grams: Double, _ color: Color, totals: MealTotals) -> some View {
        let calFactor = label == "Fat" ? 9.0 : 4.0
        let pct = totals.calories > 0 ? (grams * calFactor / totals.calories) : 0
        return VStack(spacing: 4) {
            Text("\(Int(grams))g")
                .font(Theme.Fonts.stat(18))
                .foregroundStyle(color)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color).frame(width: geo.size.width * min(pct, 1))
                }
            }
            .frame(height: 6)
            Text("\(label) · \(Int(pct * 100))%")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func secondaryStat(_ label: String, _ value: Double, _ unit: String) -> some View {
        HStack(spacing: 3) {
            Text(label).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textTertiary)
            Text("\(value, specifier: "%.1f")\(unit)")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func confidenceCard(_ confidence: Double) -> some View {
        let pct = Int(confidence * 100)
        let color: Color = confidence >= 0.8 ? Theme.Colors.safe : (confidence >= 0.6 ? Theme.Colors.caution : Theme.Colors.danger)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI confidence")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text("\(pct)%")
                    .font(Theme.Fonts.stat(20))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Colors.surfaceRaised)
                    Capsule().fill(color).frame(width: geo.size.width * confidence)
                }
            }
            .frame(height: 6)
            if confidence < 0.8 {
                Text("Some portions were estimated — tap an ingredient to adjust it.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .card()
    }

    private func allergenCard(_ verdict: AllergenVerdict) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !verdict.contains.isEmpty {
                Text("Contains")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.danger)
                FlowTags(items: verdict.contains, icon: "xmark.shield.fill", color: Theme.Colors.danger)
            }
            Text("Safe")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.safe)
            FlowTags(items: Array(verdict.safe.prefix(6)) + (verdict.safe.count > 6 ? ["+\(verdict.safe.count - 6) more"] : []),
                     icon: "checkmark.shield.fill", color: Theme.Colors.safe)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func ingredientRow(_ item: AnalyzedItem) -> some View {
        HStack(spacing: 12) {
            Button {
                editingItem = item
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: item.needsReview ? "questionmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(item.needsReview ? Theme.Colors.caution : Theme.Colors.safe)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName(item))
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                        // calories · protein · carbs, right beside every ingredient
                        HStack(spacing: 10) {
                            statPair("\(Int(item.calories))", "kcal", Theme.Colors.textPrimary)
                            statPair("\(Int(item.protein))g", "protein", Theme.Colors.protein)
                            statPair("\(Int(item.carbs))g", "carbs", Theme.Colors.carbs)
                        }
                        if item.needsReview {
                            Text("No database match — tap to review")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.caution)
                        } else if item.portionEstimated {
                            Text("portion estimated · \(Int(item.grams))g")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            if swappingItemId == item.id {
                ProgressView()
                    .tint(Theme.Colors.volt)
                    .frame(width: 36, height: 36)
            } else if item.swappable && !item.substitutes.isEmpty {
                Menu {
                    Section("Swap for") {
                        ForEach(item.substitutes, id: \.self) { sub in
                            Button(sub) { swapItem(item, to: sub) }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Theme.Colors.onVolt, Theme.Colors.volt)
                }
            }
        }
        .card()
    }

    private func statPair(_ value: String, _ label: String, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(Theme.Fonts.stat(15))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }

    /// Swap an ingredient for a substitute: re-runs the USDA pipeline for the
    /// substitute at the same portion size, then rebalances totals + allergens.
    private func swapItem(_ item: AnalyzedItem, to substitute: String) {
        swappingItemId = item.id
        errorMessage = nil
        Task {
            defer { swappingItemId = nil }
            do {
                let grams = max(Int(item.grams.rounded()), 1)
                let response = try await AIMealService.analyze(
                    messages: [.init(role: "user", content: "\(grams) grams of \(substitute)")],
                    allergens: allergenSlugs
                )
                guard let newItem = response.meal?.items.first,
                      var m = meal,
                      let idx = m.items.firstIndex(of: item) else {
                    errorMessage = "Couldn't get nutrition for \(substitute) — try editing the ingredient instead."
                    return
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    m.items[idx] = newItem
                    m.totals = recomputeTotals(m.items)
                    let contains = Array(Set(m.items.flatMap(\.allergens))).sorted()
                    let all = Set(m.allergens.contains + m.allergens.safe)
                    m.allergens = AllergenVerdict(contains: contains,
                                                  safe: all.filter { !contains.contains($0) }.sorted())
                    meal = m
                }
            } catch {
                errorMessage = "Swap failed: \(error.localizedDescription)"
            }
        }
    }

    private func displayName(_ item: AnalyzedItem) -> String {
        var parts: [String] = []
        if item.quantity > 0 {
            let q = item.quantity == item.quantity.rounded() ? String(Int(item.quantity)) : String(item.quantity)
            parts.append(q)
        }
        if !item.unit.isEmpty { parts.append(item.unit) }
        if !item.preparation.isEmpty { parts.append(item.preparation) }
        parts.append(item.food.capitalized)
        return parts.joined(separator: " ")
    }

    private func detailLine(_ item: AnalyzedItem) -> String {
        if item.needsReview { return "No database match — tap to review" }
        var line = "\(Int(item.grams))g · P \(Int(item.protein)) · C \(Int(item.carbs)) · F \(Int(item.fat))"
        if item.portionEstimated { line += " · portion estimated" }
        return line
    }

    // MARK: - Actions

    private func startAnalysis() {
        conversation = [.init(role: "user", content: mealText)]
        runAnalysis()
    }

    private func submitAnswer() {
        conversation.append(.init(role: "assistant", content: questions.joined(separator: "\n")))
        conversation.append(.init(role: "user", content: answerText))
        answerText = ""
        runAnalysis()
    }

    private func runAnalysis() {
        errorMessage = nil
        withAnimation { phase = .loading }
        Task {
            do {
                let response = try await AIMealService.analyze(messages: conversation, allergens: allergenSlugs)
                withAnimation {
                    if response.needsClarification, let qs = response.questions, !qs.isEmpty {
                        questions = qs
                        phase = .clarifying
                    } else if let analyzed = response.meal {
                        meal = analyzed
                        phase = .result
                    } else {
                        errorMessage = "I'm not confident I understood your meal. Could you describe it with a little more detail?"
                        phase = .input
                    }
                }
            } catch {
                withAnimation {
                    errorMessage = error.localizedDescription
                    phase = .input
                }
            }
        }
    }

    private func applyEdit(_ updated: AnalyzedItem, original: AnalyzedItem) {
        guard var m = meal, let idx = m.items.firstIndex(of: original) else { return }
        m.items[idx] = updated
        m.totals = recomputeTotals(m.items)
        let contains = Array(Set(m.items.flatMap(\.allergens))).sorted()
        m.allergens = AllergenVerdict(contains: contains,
                                      safe: m.allergens.safe.filter { !contains.contains($0) } + m.allergens.contains.filter { !contains.contains($0) })
        meal = m
    }

    private func recomputeTotals(_ items: [AnalyzedItem]) -> MealTotals {
        func sum(_ kp: KeyPath<AnalyzedItem, Double>) -> Double {
            ((items.reduce(0) { $0 + $1[keyPath: kp] }) * 10).rounded() / 10
        }
        return MealTotals(calories: sum(\.calories), protein: sum(\.protein), carbs: sum(\.carbs),
                          fat: sum(\.fat), fiber: sum(\.fiber), sugar: sum(\.sugar), sodium: sum(\.sodium))
    }

    private func saveMeal(_ analyzed: AnalyzedMeal) async {
        if !session.isDemo, let userId = session.session?.user.id {
            struct AIMealRecord: Codable {
                let userId: UUID, name: String, mealType: String
                let ingredients: [IngredientJSON]
                let calories: Int, proteinG: Double, carbsG: Double, fatG: Double, fiberG: Double
                let sugarG: Double, sodiumMg: Double, detectedAllergens: [String], confidence: Double
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id", name, mealType = "meal_type", ingredients, calories
                    case proteinG = "protein_g", carbsG = "carbs_g", fatG = "fat_g", fiberG = "fiber_g"
                    case sugarG = "sugar_g", sodiumMg = "sodium_mg"
                    case detectedAllergens = "detected_allergens", confidence
                }
            }
            struct IngredientJSON: Codable {
                let name: String, grams: Double, allergens: [String]
            }
            let record = AIMealRecord(
                userId: userId, name: analyzed.name, mealType: "snack",
                ingredients: analyzed.items.map { .init(name: $0.food, grams: $0.grams, allergens: $0.allergens) },
                calories: Int(analyzed.totals.calories), proteinG: analyzed.totals.protein,
                carbsG: analyzed.totals.carbs, fatG: analyzed.totals.fat, fiberG: analyzed.totals.fiber,
                sugarG: analyzed.totals.sugar, sodiumMg: analyzed.totals.sodium,
                detectedAllergens: analyzed.allergens.contains, confidence: analyzed.confidence
            )
            do {
                try await Backend.client.from("meal_logs").insert(record).execute()
            } catch {
                errorMessage = "Save failed: \(error.localizedDescription)"
                return
            }
        }
        withAnimation { phase = .saved }
    }

    private func reset() {
        withAnimation {
            phase = .input
            meal = nil
            conversation = []
            questions = []
            mealText = ""
            errorMessage = nil
        }
    }
}

// MARK: - Edit ingredient sheet

struct EditIngredientSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: AnalyzedItem
    let onSave: (AnalyzedItem) -> Void

    @State private var grams: Double

    init(item: AnalyzedItem, onSave: @escaping (AnalyzedItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _grams = State(initialValue: item.grams)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text(item.food.capitalized)
                        .font(Theme.Fonts.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    if let desc = item.fdcDescription {
                        Text("USDA match: \(desc)")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Amount")
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(grams))g")
                                .font(Theme.Fonts.stat(24))
                                .foregroundStyle(Theme.Colors.volt)
                        }
                        Slider(value: $grams, in: 5...max(500, item.grams * 2), step: 5)
                            .tint(Theme.Colors.volt)
                    }
                    .card()

                    let preview = item.scaled(toGrams: grams)
                    HStack(spacing: 14) {
                        stat("\(Int(preview.calories))", "kcal")
                        stat("\(Int(preview.protein))g", "protein")
                        stat("\(Int(preview.carbs))g", "carbs")
                        stat("\(Int(preview.fat))g", "fat")
                    }

                    Spacer()

                    Button {
                        onSave(item.scaled(toGrams: grams))
                        dismiss()
                    } label: {
                        Text("Update")
                            .font(Theme.Fonts.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Theme.Colors.volt)
                            .foregroundStyle(Theme.Colors.onVolt)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(Theme.Metrics.screenPadding)
            }
            .navigationTitle("Edit ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(Theme.Fonts.stat(18)).foregroundStyle(Theme.Colors.textPrimary)
            Text(label).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}

// MARK: - Flowing tag row

struct FlowTags: View {
    let items: [String]
    let icon: String
    let color: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6)], spacing: 6) {
            ForEach(items, id: \.self) { tag in
                Label(tag, systemImage: icon)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(color.opacity(0.1), in: Capsule())
            }
        }
    }
}
