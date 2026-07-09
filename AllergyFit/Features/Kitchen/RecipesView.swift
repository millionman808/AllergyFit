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

    var isSafe: Bool { flagged.isEmpty }
    var isUnverified: Bool { flagged.contains("__unverified__") }
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
    private var loadedSaved = false

    func configure(session: SessionStore) {
        isDemo = session.isDemo
        userId = session.session?.user.id
        if !loadedSaved {
            loadedSaved = true
            Task { await loadSaved() }
        }
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

    func toggleSave(_ recipe: Recipe) {
        if isSaved(recipe) {
            saved.removeAll { $0.url == recipe.url }
            if !isDemo, userId != nil {
                Task {
                    try? await Backend.client.from("saved_recipes")
                        .delete().eq("url", value: recipe.url).execute()
                }
            }
        } else {
            saved.insert(recipe, at: 0)
            if !isDemo, let userId {
                struct Row: Codable {
                    let user_id: UUID, title: String, url: String
                    let image_url: String, ingredients: [String], calories: Int?
                }
                let row = Row(user_id: userId, title: recipe.title, url: recipe.url,
                              image_url: recipe.image, ingredients: recipe.ingredients,
                              calories: recipe.calories)
                Task { try? await Backend.client.from("saved_recipes").insert(row).execute() }
            }
        }
    }

    private func loadSaved() async {
        guard !isDemo, userId != nil else { return }
        struct Row: Codable {
            let title: String, url: String, image_url: String?
            let ingredients: [String]?, calories: Int?
        }
        do {
            let rows: [Row] = try await Backend.client.from("saved_recipes")
                .select("title, url, image_url, ingredients, calories")
                .order("created_at", ascending: false)
                .execute().value
            saved = rows.map {
                Recipe(title: $0.title, url: $0.url, image: $0.image_url ?? "",
                       calories: $0.calories, ingredients: $0.ingredients ?? [], flagged: [])
            }
        } catch {
            print("load saved failed: \(error)")
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
    let recipe: Recipe
    @ObservedObject var store: RecipeStore

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
                            if let url = URL(string: recipe.url) {
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
        }
    }
}
