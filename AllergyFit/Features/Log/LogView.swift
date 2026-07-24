import SwiftUI

/// Logging hub → meal / workout / symptom flows.
struct LogView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var quick = QuickLogStore()
    @State private var toast: String?
    @State private var path: [String] = {
        if let screen = UserDefaults.standard.string(forKey: "logScreen") { return [screen] }
        return []
    }()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Metrics.spacing) {
                        NavigationLink(value: "meal") {
                            logButton("Log a meal", subtitle: "Snap a photo or describe it — AI works out the nutrition", icon: "sparkles", color: Theme.Colors.volt)
                        }
                        NavigationLink(value: "workout") {
                            logButton("Log a workout", subtitle: "Type, duration, intensity", icon: "dumbbell.fill", color: Theme.Colors.protein)
                        }
                        NavigationLink(value: "symptom") {
                            logButton("Check-in", subtitle: "Log a good day or a reaction — feeds your patterns", icon: "heart.text.square.fill", color: Theme.Colors.danger)
                        }
                        NavigationLink(value: "barcode") {
                            logButton("Scan a product", subtitle: "Instant safe/unsafe verdict + macros", icon: "barcode.viewfinder", color: Theme.Colors.caution)
                        }

                        quickAdd
                    }
                    .padding(Theme.Metrics.screenPadding)
                    .padding(.bottom, Theme.Metrics.tabBarClearance)
                }

                if let toast {
                    VStack {
                        Spacer()
                        Label(toast, systemImage: "checkmark.circle.fill")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.onVolt)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(Theme.Colors.volt, in: Capsule())
                            .padding(.bottom, Theme.Metrics.tabBarClearance)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Log")
            .onAppear { quick.configure(session: session) }
            .navigationDestination(for: String.self) { screen in
                switch screen {
                case "meal": AIMealLogView()
                case "workout": WorkoutLogView()
                case "barcode": BarcodeScannerView()
                default: SymptomLogView()
                }
            }
        }
    }

    private func reLog(_ meal: QuickLogStore.RecentMeal) {
        Haptics.success()
        Task {
            let ok = await quick.reLog(meal)
            await MainActor.run {
                withAnimation { toast = ok ? "Logged \(meal.name)" : "Couldn't log that — try again" }
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { withAnimation { toast = nil } }
        }
    }

    private func logButton(_ title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(subtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .card()
    }

    @ViewBuilder private var quickAdd: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
            Text("Quick re-log")
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.top, 8)
            if quick.recent.isEmpty {
                Text("Meals you log show up here for one-tap re-logging.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            } else {
                ForEach(quick.recent) { meal in
                    Button { reLog(meal) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: meal.icon)
                                .foregroundStyle(Theme.Colors.volt)
                                .frame(width: 38, height: 38)
                                .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.name)
                                    .font(Theme.Fonts.headline)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                Text("\(meal.calories) kcal · \(meal.protein)g protein")
                                    .font(Theme.Fonts.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.Colors.volt)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Recent distinct meals for one-tap re-logging.
@MainActor
final class QuickLogStore: ObservableObject {
    struct RecentMeal: Identifiable {
        let id = UUID()
        let name: String
        let mealTypeDB: String
        let icon: String
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
    }

    @Published var recent: [RecentMeal] = []
    private var isDemo = false
    private var userId: UUID?
    private var configured = false

    func configure(session: SessionStore) {
        isDemo = session.isDemo
        userId = session.session?.user.id
        if isDemo {
            recent = MockData.todayMeals.map {
                RecentMeal(name: $0.name, mealTypeDB: dbType($0.mealType), icon: $0.icon,
                           calories: $0.calories, protein: $0.protein, carbs: $0.carbs, fat: $0.fat)
            }
        } else if !configured {
            configured = true
            Task { await load() }
        }
    }

    func load() async {
        guard let userId else { return }
        struct Row: Codable {
            let name: String, mealType: String
            let calories: Int?, proteinG: Double?, carbsG: Double?, fatG: Double?
            enum CodingKeys: String, CodingKey {
                case name; case mealType = "meal_type"; case calories
                case proteinG = "protein_g"; case carbsG = "carbs_g"; case fatG = "fat_g"
            }
        }
        do {
            let rows: [Row] = try await Backend.client
                .from("meal_logs")
                .select("name, meal_type, calories, protein_g, carbs_g, fat_g, eaten_at")
                .eq("user_id", value: userId)
                .order("eaten_at", ascending: false)
                .limit(50)
                .execute().value
            var seen = Set<String>()
            var out: [RecentMeal] = []
            for r in rows {
                let key = r.name.lowercased()
                if seen.contains(key) { continue }
                seen.insert(key)
                out.append(RecentMeal(name: r.name, mealTypeDB: r.mealType,
                                      icon: TodayMeal.icon(for: r.mealType),
                                      calories: r.calories ?? 0, protein: Int(r.proteinG ?? 0),
                                      carbs: Int(r.carbsG ?? 0), fat: Int(r.fatG ?? 0)))
                if out.count >= 8 { break }
            }
            recent = out
        } catch {
            print("recent meals load failed: \(error)")
        }
    }

    /// Re-log a meal at the current time. Returns false on a save error.
    func reLog(_ meal: RecentMeal) async -> Bool {
        guard !isDemo, let userId else { return true }   // demo: pretend success
        let record = MealLogRecord(id: UUID(), userId: userId, eatenAt: Date(),
                                   mealType: meal.mealTypeDB, name: meal.name,
                                   calories: meal.calories, proteinG: Double(meal.protein),
                                   carbsG: Double(meal.carbs), fatG: Double(meal.fat))
        do {
            try await Backend.client.from("meal_logs").insert(record).execute()
            return true
        } catch {
            print("re-log failed: \(error)")
            return false
        }
    }

    private func dbType(_ display: String) -> String {
        display.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
}

// MARK: - Meal logging

struct MealLogView: View {
    @State private var search = ""
    @State private var selectedType = "Lunch"
    private let types = ["Breakfast", "Lunch", "Dinner", "Snack", "Pre-workout", "Post-workout"]

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Theme.Metrics.spacing) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.Colors.textTertiary)
                        TextField("Search foods…", text: $search)
                            .font(Theme.Fonts.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .padding(14)
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(types, id: \.self) { t in
                                Button {
                                    selectedType = t
                                } label: {
                                    Text(t)
                                        .font(Theme.Fonts.caption)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedType == t ? Theme.Colors.volt : Theme.Colors.surface)
                                        .foregroundStyle(selectedType == t ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    resultRow("Grilled Chicken Breast", "6 oz · 280 kcal · 52g protein", safe: true)
                    resultRow("Jasmine Rice, cooked", "1 cup · 205 kcal · 4g protein", safe: true)
                    resultRow("Protein Bar — ChocoCrunch", "Contains: peanut, dairy", safe: false)
                    resultRow("Avocado", "1 whole · 240 kcal · 3g protein", safe: true)
                    resultRow("Greek Yogurt", "Contains: dairy", safe: false)
                }
                .padding(Theme.Metrics.screenPadding)
            }
        }
        .navigationTitle("Log a meal")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func resultRow(_ name: String, _ detail: String, safe: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: safe ? "checkmark.shield.fill" : "xmark.shield.fill")
                .font(.title3)
                .foregroundStyle(safe ? Theme.Colors.safe : Theme.Colors.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(detail)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(safe ? Theme.Colors.textSecondary : Theme.Colors.danger)
            }
            Spacer()
            if safe {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.volt)
            }
        }
        .card()
        .opacity(safe ? 1 : 0.75)
    }
}

// MARK: - Workout logging

struct WorkoutLogView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var type = "Lifting"
    @State private var minutes: Double = 60
    @State private var intensity = "Hard"
    @State private var isSaving = false
    @State private var saved = false
    @State private var errorMessage: String?
    private let types = ["Lifting", "Running", "CrossFit", "Cycling", "Swimming", "HIIT", "Team sport", "Yoga"]
    private let intensities = ["Light", "Moderate", "Hard", "Max"]

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Type")
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                        ForEach(types, id: \.self) { t in
                            Button {
                                type = t
                            } label: {
                                Text(t)
                                    .font(Theme.Fonts.caption)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(type == t ? Theme.Colors.volt : Theme.Colors.surface)
                                    .foregroundStyle(type == t ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Duration")
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(minutes)) min")
                                .font(Theme.Fonts.stat(22))
                                .foregroundStyle(Theme.Colors.volt)
                        }
                        Slider(value: $minutes, in: 10...180, step: 5)
                            .tint(Theme.Colors.volt)
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Intensity")
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        HStack(spacing: 8) {
                            ForEach(intensities, id: \.self) { i in
                                Button {
                                    intensity = i
                                } label: {
                                    Text(i)
                                        .font(Theme.Fonts.caption)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 42)
                                        .background(intensity == i ? Theme.Colors.volt : Theme.Colors.surface)
                                        .foregroundStyle(intensity == i ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }
                    }
                    .card()

                    if let errorMessage {
                        Text(errorMessage).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.danger)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        Group {
                            if isSaving { ProgressView().tint(Theme.Colors.onVolt) }
                            else if saved { Label("Saved", systemImage: "checkmark") }
                            else { Text("Save Workout") }
                        }
                        .font(Theme.Fonts.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(saved ? Theme.Colors.safe : Theme.Colors.volt)
                        .foregroundStyle(Theme.Colors.onVolt)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isSaving || saved)
                }
                .padding(Theme.Metrics.screenPadding)
            }
        }
        .navigationTitle("Log a workout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        if !session.isDemo, let userId = session.session?.user.id {
            do {
                try await LogService.saveWorkout(userId: userId, type: type, minutes: Int(minutes), intensity: intensity)
            } catch {
                errorMessage = "Couldn't save: \(error.localizedDescription)"
                return
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
    }
}

// MARK: - Symptom check-in

struct SymptomLogView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    enum Mood { case good, reaction }
    @State private var mood: Mood = .good
    @State private var selected: Set<String> = []
    @State private var severity = "Mild"
    @State private var duringExercise = false
    @State private var foodText = ""
    @State private var isSaving = false
    @State private var saved = false
    @State private var errorMessage: String?
    private let severities = ["Mild", "Moderate", "Severe"]

    private var canSave: Bool { mood == .good || !selected.isEmpty }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How are you feeling?")
                        .font(Theme.Fonts.title)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    // Good days matter as much as bad ones — both train the
                    // pattern engine on what's safe for you.
                    HStack(spacing: 10) {
                        moodButton("All good", systemImage: "checkmark.circle.fill", value: .good, color: Theme.Colors.safe)
                        moodButton("Had a reaction", systemImage: "exclamationmark.triangle.fill", value: .reaction, color: Theme.Colors.danger)
                    }

                    // What you ate — the food side of the correlation.
                    VStack(alignment: .leading, spacing: 8) {
                        Text(mood == .good ? "What did you eat? (optional)" : "What did you eat before this?")
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        TextField("e.g. turkey sandwich, protein shake", text: $foodText, axis: .vertical)
                            .font(Theme.Fonts.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1...3)
                            .padding(12)
                            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if mood == .reaction {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Symptoms")
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            FlowChips(items: MockData.symptoms, selected: $selected)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Severity")
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            HStack(spacing: 8) {
                                ForEach(severities, id: \.self) { s in
                                    Button {
                                        severity = s
                                    } label: {
                                        Text(s)
                                            .font(Theme.Fonts.caption)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 42)
                                            .background(severity == s ? severityColor(s) : Theme.Colors.surface)
                                            .foregroundStyle(severity == s ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                }
                            }
                        }
                        .card()

                        Toggle(isOn: $duringExercise) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("During or after exercise?")
                                    .font(Theme.Fonts.headline)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text("Helps detect exercise-induced reactions")
                                    .font(Theme.Fonts.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                        .tint(Theme.Colors.volt)
                        .card()
                    }

                    if let errorMessage {
                        Text(errorMessage).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.danger)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        Group {
                            if isSaving { ProgressView().tint(Theme.Colors.onVolt) }
                            else if saved { Label("Saved", systemImage: "checkmark") }
                            else { Text(mood == .good ? "Log a good day" : "Save check-in") }
                        }
                        .font(Theme.Fonts.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(saved ? Theme.Colors.safe : (canSave ? Theme.Colors.volt : Theme.Colors.surfaceRaised))
                        .foregroundStyle(canSave || saved ? Theme.Colors.onVolt : Theme.Colors.textTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!canSave || isSaving || saved)

                    Text("If you're experiencing a severe reaction, use your epinephrine and call emergency services. AllergyFit is not a medical device.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .padding(Theme.Metrics.screenPadding)
                .padding(.bottom, Theme.Metrics.tabBarClearance)
            }
        }
        .navigationTitle("Check-in")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func moodButton(_ title: String, systemImage: String, value: Mood, color: Color) -> some View {
        Button {
            withAnimation { mood = value }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.title3)
                Text(title).font(Theme.Fonts.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(mood == value ? color.opacity(0.16) : Theme.Colors.surface,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(mood == value ? color : .clear, lineWidth: 1.5))
            .foregroundStyle(mood == value ? color : Theme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let symptoms = mood == .reaction ? Array(selected) : []
        if !session.isDemo, let userId = session.session?.user.id {
            do {
                try await LogService.saveSymptom(
                    userId: userId, symptoms: symptoms,
                    severity: mood == .reaction ? severity : "mild",
                    duringExercise: mood == .reaction ? duringExercise : false,
                    notes: foodText)
            } catch {
                errorMessage = "Couldn't save: \(error.localizedDescription)"
                return
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
    }

    private func severityColor(_ s: String) -> Color {
        switch s {
        case "Mild": return Theme.Colors.caution
        case "Moderate": return Color.orange
        default: return Theme.Colors.danger
        }
    }
}
