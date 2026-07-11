import SwiftUI
import Supabase

// MARK: - Models

struct Recipe: Codable, Identifiable, Equatable {
    var id: String { url }
    var title: String
    var url: String
    var image: String
    var calories: Int?
    var ingredients: [String]
    var flagged: [String]
    // Optional so older cached saves / older API responses still decode cleanly.
    var directions: [String]? = nil
    var protein: Int? = nil
    var carbs: Int? = nil
    var fat: Int? = nil
    var servings: Int? = nil

    var isSafe: Bool { flagged.isEmpty }
    var isUnverified: Bool { flagged.contains("__unverified__") }
    var steps: [String] { directions ?? [] }
    var hasNutrition: Bool { calories != nil || protein != nil || carbs != nil || fat != nil }
    var hasMacros: Bool { protein != nil || carbs != nil || fat != nil }
    /// Calorie estimate from macros (Atwater): 4·protein + 4·carbs + 9·fat.
    var atwaterCalories: Int? {
        guard let p = protein, let c = carbs, let f = fat else { return nil }
        return p * 4 + c * 4 + f * 9
    }
}

// MARK: - Store

@MainActor
final class RecipeStore: ObservableObject {
    @Published var results: [Recipe] = []
    @Published var saved: [Recipe] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    private var isDemo = true
    private var userId: UUID?
    private var configured = false

    /// Local cache key — separate buckets for demo and each signed-in user.
    private var storageKey: String {
        isDemo ? "savedRecipes.demo" : "savedRecipes.\(userId?.uuidString ?? "anon")"
    }

    func configure(session: SessionStore) {
        let newDemo = session.isDemo
        let newUser = session.session?.user.id
        // Re-run whenever identity changes (e.g. the session finishes loading
        // after the view first appears), not just once.
        guard !configured || newDemo != isDemo || newUser != userId else { return }
        configured = true
        isDemo = newDemo
        userId = newUser
        loadLocal()                                                  // instant, survives relaunch
        if !isDemo, userId != nil { Task { await loadSaved() } }     // merge cross-device rows
    }

    func search(_ query: String, allergens: [String]) async {
        guard !query.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            let url = Config.supabaseURL.appendingPathComponent("functions/v1/recipes")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 60
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(Config.supabasePublishableKey, forHTTPHeaderField: "apikey")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query, "allergens": allergens])
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Payload: Codable { var results: [Recipe] }
            results = try JSONDecoder().decode(Payload.self, from: data).results
            if results.isEmpty {
                errorMessage = "No recipes found — try a simpler search like \"chicken\" or \"pasta\"."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isSaved(_ recipe: Recipe) -> Bool {
        saved.contains { $0.url == recipe.url }
    }

    private struct SavedRow: Codable {
        let user_id: UUID, title: String, url: String
        let image_url: String, ingredients: [String], calories: Int?
        let directions: [String], protein: Int?, carbs: Int?, fat: Int?
    }

    private func savedRow(_ r: Recipe, _ userId: UUID) -> SavedRow {
        SavedRow(user_id: userId, title: r.title, url: r.url,
                 image_url: r.image, ingredients: r.ingredients, calories: r.calories,
                 directions: r.directions ?? [], protein: r.protein, carbs: r.carbs, fat: r.fat)
    }

    func toggleSave(_ recipe: Recipe) {
        if isSaved(recipe) {
            saved.removeAll { $0.url == recipe.url }
            persistLocal()
            if !isDemo, userId != nil {
                Task {
                    do {
                        try await Backend.client.from("saved_recipes")
                            .delete().eq("url", value: recipe.url).execute()
                    } catch { print("saved_recipes delete failed: \(error)") }
                }
            }
        } else {
            saved.insert(recipe, at: 0)
            persistLocal()
            if !isDemo, let userId {
                let row = savedRow(recipe, userId)
                Task {
                    do {
                        try await Backend.client.from("saved_recipes")
                            .upsert(row, onConflict: "user_id,url").execute()
                    } catch { print("saved_recipes save failed: \(error)") }
                }
            }
        }
    }

    /// Replace a saved recipe in place (e.g. after filling in computed nutrition).
    func updateSaved(_ recipe: Recipe) {
        guard let idx = saved.firstIndex(where: { $0.url == recipe.url }) else { return }
        saved[idx] = recipe
        persistLocal()
        guard !isDemo, let userId else { return }
        let row = savedRow(recipe, userId)
        Task {
            do {
                try await Backend.client.from("saved_recipes")
                    .upsert(row, onConflict: "user_id,url").execute()
            } catch { print("saved_recipes nutrition update failed: \(error)") }
        }
    }

    // MARK: Local cache (survives relaunch regardless of auth/network)

    private func loadLocal() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let recipes = try? JSONDecoder().decode([Recipe].self, from: data) {
            saved = recipes
        } else {
            saved = []
        }
    }

    private func persistLocal() {
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadSaved() async {
        guard !isDemo, let userId else { return }
        struct Row: Codable {
            let title: String, url: String, image_url: String?
            let ingredients: [String]?, calories: Int?
            let directions: [String]?, protein: Int?, carbs: Int?, fat: Int?
        }
        do {
            let rows: [Row] = try await Backend.client.from("saved_recipes")
                .select("title, url, image_url, ingredients, calories, directions, protein, carbs, fat")
                .order("created_at", ascending: false)
                .execute().value
            let remote = rows.map {
                Recipe(title: $0.title, url: $0.url, image: $0.image_url ?? "",
                       calories: $0.calories, ingredients: $0.ingredients ?? [], flagged: [],
                       directions: $0.directions, protein: $0.protein, carbs: $0.carbs, fat: $0.fat)
            }
            // Merge remote + local by url. Local is kept when present (it carries the
            // richest copy — directions/macros captured at save time); remote-only rows
            // are appended so nothing is dropped.
            let localByURL = Dictionary(saved.map { ($0.url, $0) }, uniquingKeysWith: { a, _ in a })
            var merged = saved
            for r in remote where localByURL[r.url] == nil { merged.append(r) }
            saved = merged
            persistLocal()
            // Back-fill any local-only saves that never reached the DB (self-heal),
            // and refresh rows that gained directions/macros locally.
            for r in merged {
                try? await Backend.client.from("saved_recipes")
                    .upsert(savedRow(r, userId), onConflict: "user_id,url").execute()
            }
        } catch {
            print("load saved failed: \(error)")   // keep local cache on failure
        }
    }
}

// MARK: - View

struct RecipesView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var planStore: PlanStore
    @StateObject private var store = RecipeStore()
    @State private var plannedToast: String?
    @State private var query = ""
    @State private var mode = 0        // 0 = search, 1 = saved
    @State private var showFlagged = false
    @State private var selectedRecipe: Recipe?
    @State private var showGenerate = false

    private var allergenSlugs: [String] { session.allergenSlugs }
    private var allergenNames: [String] {
        session.allergenSlugs.map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Metrics.spacing) {
                searchBar
                generateBanner
                filterRow

                if store.isSearching {
                    VStack(spacing: 12) {
                        ProgressView().tint(Theme.Colors.volt)
                        Text("Finding recipes safe for you…")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.vertical, 60)
                } else if mode == 1 {
                    savedList
                } else {
                    resultsList
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 24)
        }
        .onAppear {
            store.configure(session: session)
            if let q = UserDefaults.standard.string(forKey: "recipeQuery"),
               store.results.isEmpty, !store.isSearching {
                query = q
                Task { await store.search(q, allergens: allergenSlugs) }
            }
        }
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe, store: store)
        }
        .sheet(isPresented: $showGenerate) {
            AIRecipeView { saved in
                if !store.isSaved(saved) { store.toggleSave(saved) }
            }
        }
    }

    private var generateBanner: some View {
        Button { showGenerate = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.onVolt)
                    .frame(width: 40, height: 40)
                    .background(Theme.Colors.volt, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generate a recipe with Volt")
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Safe for your triggers, from a craving or your fridge")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.textTertiary)
            }
            .card()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Colors.textTertiary)
            TextField("Search recipes… (\"chicken\", \"curry\")", text: $query)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .submitLabel(.search)
                .onSubmit {
                    mode = 0
                    Task { await store.search(query, allergens: allergenSlugs) }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        .padding(14)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            chip("Search", active: mode == 0) { mode = 0 }
            chip("Saved (\(store.saved.count))", active: mode == 1) { mode = 1 }
            Spacer()
            if mode == 0 {
                Button {
                    showFlagged.toggle()
                } label: {
                    Label(showFlagged ? "Hiding nothing" : "Safe only",
                          systemImage: showFlagged ? "eye" : "checkmark.shield.fill")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(showFlagged ? Theme.Colors.textSecondary : Theme.Colors.safe)
                }
            }
        }
    }

    private func planToDay(_ recipe: Recipe, _ day: Int) {
        planStore.add(recipe, to: day)
        withAnimation { plannedToast = "\(recipe.title) added to \(PlanStore.dayNames[day])" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { plannedToast = nil }
        }
    }

    private func chip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.Fonts.caption)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(active ? Theme.Colors.volt : Theme.Colors.surface)
                .foregroundStyle(active ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        let visible = showFlagged ? store.results : store.results.filter(\.isSafe)
        if let error = store.errorMessage {
            Text(error)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.vertical, 30)
        } else if visible.isEmpty && store.results.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Colors.textTertiary)
                Text("Search for anything — results are pre-checked against your triggers: \(allergenNames.joined(separator: ", "))")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 50)
        } else {
            if let plannedToast {
                Label(plannedToast, systemImage: "calendar.badge.checkmark")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.safe)
                    .frame(maxWidth: .infinity)
            }
            ForEach(visible) { recipe in
                RecipeCard(recipe: recipe, saved: store.isSaved(recipe)) {
                    selectedRecipe = recipe
                } onSave: {
                    store.toggleSave(recipe)
                } onPlan: { day in
                    planToDay(recipe, day)
                }
            }
            if !showFlagged {
                let hidden = store.results.count - visible.count
                if hidden > 0 {
                    Text("\(hidden) recipe\(hidden == 1 ? "" : "s") hidden because they contain your triggers")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var savedList: some View {
        if store.saved.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "heart")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Colors.textTertiary)
                Text("Recipes you save show up here")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.vertical, 50)
        } else {
            ForEach(store.saved) { recipe in
                RecipeCard(recipe: recipe, saved: true) {
                    selectedRecipe = recipe
                } onSave: {
                    store.toggleSave(recipe)
                } onPlan: { day in
                    planToDay(recipe, day)
                }
            }
        }
    }
}

// MARK: - Card

struct RecipeCard: View {
    let recipe: Recipe
    let saved: Bool
    let onTap: () -> Void
    let onSave: () -> Void
    var onPlan: (Int) -> Void = { _ in }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: recipe.image)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Theme.Colors.surfaceRaised
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                )
                        }
                    }
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Button(action: onSave) {
                        Image(systemName: saved ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(saved ? Theme.Colors.danger : .white)
                            .padding(9)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    .padding(10)
                }

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(recipe.title)
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            if recipe.isUnverified {
                                Label("Couldn't verify ingredients", systemImage: "questionmark.circle")
                                    .foregroundStyle(Theme.Colors.caution)
                            } else if recipe.isSafe {
                                Label("No flagged ingredients", systemImage: "checkmark.shield.fill")
                                    .foregroundStyle(Theme.Colors.safe)
                            } else {
                                Label("Contains \(recipe.flagged.joined(separator: ", "))", systemImage: "exclamationmark.shield.fill")
                                    .foregroundStyle(Theme.Colors.danger)
                            }
                        }
                        .font(Theme.Fonts.caption)
                        .lineLimit(1)
                    }
                    Spacer()
                    if let cal = recipe.calories {
                        VStack(spacing: 1) {
                            Text("\(cal)")
                                .font(Theme.Fonts.stat(16))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("kcal")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                    }
                    Menu {
                        Section("Add to plan") {
                            ForEach(0..<7, id: \.self) { day in
                                Button(PlanStore.dayNames[day]) { onPlan(day) }
                            }
                        }
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.Colors.volt)
                            .padding(8)
                            .background(Theme.Colors.surfaceRaised, in: Circle())
                    }
                }
                .padding(12)
            }
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
        }
    }
}

// MARK: - Detail

struct RecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recipe: Recipe
    @ObservedObject var store: RecipeStore
    @State private var calculating = false
    @State private var calcError: String?
    @State private var justEstimated = false
    @State private var autoAttempted = false

    init(recipe: Recipe, store: RecipeStore) {
        _recipe = State(initialValue: recipe)
        self.store = store
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                        AsyncImage(url: URL(string: recipe.image)) { phase in
                            if case .success(let image) = phase {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Theme.Colors.surfaceRaised
                            }
                        }
                        .frame(height: 210)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))

                        Text(recipe.title)
                            .font(Theme.Fonts.title)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        if !recipe.flagged.isEmpty && !recipe.isUnverified {
                            Label("Contains your triggers: \(recipe.flagged.joined(separator: ", "))", systemImage: "exclamationmark.shield.fill")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.danger)
                                .card()
                        }

                        if recipe.hasNutrition || !recipe.ingredients.isEmpty {
                            Text("Nutrition")
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            HStack(spacing: 10) {
                                nutritionStat("Calories", recipe.calories, "")
                                nutritionStat("Protein", recipe.protein, "g")
                                nutritionStat("Carbs", recipe.carbs, "g")
                                nutritionStat("Fat", recipe.fat, "g")
                            }
                            nutritionFooter
                        }

                        Text("Ingredients")
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(recipe.ingredients, id: \.self) { ing in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(Theme.Colors.volt)
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 7)
                                    Text(ing)
                                        .font(Theme.Fonts.body)
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                            }
                        }
                        .card()

                        if !recipe.steps.isEmpty {
                            Text("Directions")
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { idx, step in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(idx + 1)")
                                            .font(Theme.Fonts.caption.bold())
                                            .foregroundStyle(Theme.Colors.onVolt)
                                            .frame(width: 24, height: 24)
                                            .background(Theme.Colors.volt, in: Circle())
                                        Text(step)
                                            .font(Theme.Fonts.body)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .card()
                        }

                        Text("Always verify ingredient labels when you shop — recipes and products change.")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)

                        HStack(spacing: 10) {
                            Button {
                                store.toggleSave(recipe)
                            } label: {
                                Label(store.isSaved(recipe) ? "Saved" : "Save recipe",
                                      systemImage: store.isSaved(recipe) ? "heart.fill" : "heart")
                                    .font(Theme.Fonts.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Theme.Colors.volt)
                                    .foregroundStyle(Theme.Colors.onVolt)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            if !recipe.url.hasPrefix("ai://"), let url = URL(string: recipe.url) {
                                Link(destination: url) {
                                    Image(systemName: "safari")
                                        .font(.title3)
                                        .frame(width: 52, height: 52)
                                        .background(Theme.Colors.surface)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                    }
                    .padding(Theme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.Colors.volt)
                }
            }
            .task {
                // Auto-fill missing macros from USDA the moment the recipe opens.
                guard !autoAttempted, !recipe.hasMacros, !recipe.ingredients.isEmpty else { return }
                autoAttempted = true
                await calculate()
            }
        }
    }

    @ViewBuilder
    private var nutritionFooter: some View {
        if !recipe.hasMacros && !recipe.ingredients.isEmpty {
            if calculating {
                HStack(spacing: 8) {
                    ProgressView().tint(Theme.Colors.volt)
                    Text("Estimating from ingredients…")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                }
            } else {
                Button { Task { await calculate() } } label: {
                    Label("Calculate protein, carbs & fat", systemImage: "function")
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.volt)
                }
            }
            if let calcError {
                Text(calcError).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.danger)
            }
        } else if let atw = recipe.atwaterCalories {
            HStack(spacing: 6) {
                if let cals = recipe.calories {
                    let ok = abs(atw - cals) <= max(60, Int(Double(cals) * 0.15))
                    Image(systemName: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(ok ? Theme.Colors.safe : Theme.Colors.caution)
                    Text("Macros add up to ≈\(atw) kcal vs \(cals) listed")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textTertiary)
                } else {
                    Text("≈\(atw) kcal from these macros")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            if justEstimated {
                Text("Verified from your ingredients via USDA FoodData Central.")
                    .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textTertiary)
            } else if !recipe.ingredients.isEmpty {
                if calculating {
                    HStack(spacing: 8) {
                        ProgressView().tint(Theme.Colors.volt)
                        Text("Verifying with USDA…")
                            .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                } else {
                    Button { Task { await calculate(replaceCalories: true) } } label: {
                        Label("Verify nutrition with USDA", systemImage: "checkmark.seal")
                            .font(Theme.Fonts.caption.weight(.semibold))
                            .foregroundStyle(Theme.Colors.volt)
                    }
                }
                if let calcError {
                    Text(calcError).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.danger)
                }
            }
        }
    }

    private func calculate(replaceCalories: Bool = false) async {
        calculating = true
        calcError = nil
        defer { calculating = false }
        do {
            let updated = try await RecipeNutritionService.fill(recipe, replaceCalories: replaceCalories)
            withAnimation { recipe = updated; justEstimated = true }
            store.updateSaved(updated)   // no-op if this recipe isn't saved
        } catch {
            calcError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func nutritionStat(_ label: String, _ value: Int?, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(value.map { "\($0)\(unit)" } ?? "—")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
