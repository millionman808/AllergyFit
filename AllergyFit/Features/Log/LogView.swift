import SwiftUI

/// Logging hub → meal / workout / symptom flows.
struct LogView: View {
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
                            logButton("Log a meal", subtitle: "Describe it — AI works out the nutrition", icon: "sparkles", color: Theme.Colors.volt)
                        }
                        NavigationLink(value: "workout") {
                            logButton("Log a workout", subtitle: "Type, duration, intensity", icon: "dumbbell.fill", color: Theme.Colors.protein)
                        }
                        NavigationLink(value: "symptom") {
                            logButton("Symptom check-in", subtitle: "30 seconds. Feeds your patterns.", icon: "heart.text.square.fill", color: Theme.Colors.danger)
                        }

                        quickAdd
                    }
                    .padding(Theme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Log")
            .navigationDestination(for: String.self) { screen in
                switch screen {
                case "meal": AIMealLogView()
                case "workout": WorkoutLogView()
                default: SymptomLogView()
                }
            }
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

    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
            Text("Quick re-log")
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.top, 8)
            ForEach(MockData.todayMeals) { meal in
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
        }
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
    @State private var selected: Set<String> = []
    @State private var severity = "Mild"
    @State private var duringExercise = false
    @State private var isSaving = false
    @State private var saved = false
    @State private var errorMessage: String?
    private let severities = ["Mild", "Moderate", "Severe"]

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How are you feeling?")
                        .font(Theme.Fonts.title)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    FlowChips(items: MockData.symptoms, selected: $selected)

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

                    if let errorMessage {
                        Text(errorMessage).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.danger)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        Group {
                            if isSaving { ProgressView().tint(Theme.Colors.onVolt) }
                            else if saved { Label("Saved", systemImage: "checkmark") }
                            else { Text("Save Check-in") }
                        }
                        .font(Theme.Fonts.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(saved ? Theme.Colors.safe : (selected.isEmpty ? Theme.Colors.surfaceRaised : Theme.Colors.volt))
                        .foregroundStyle(selected.isEmpty && !saved ? Theme.Colors.textTertiary : Theme.Colors.onVolt)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(selected.isEmpty || isSaving || saved)

                    Text("If you're experiencing a severe reaction, use your epinephrine and call emergency services. AllergyFit is not a medical device.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .padding(Theme.Metrics.screenPadding)
            }
        }
        .navigationTitle("Symptom check-in")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        if !session.isDemo, let userId = session.session?.user.id {
            do {
                try await LogService.saveSymptom(userId: userId, symptoms: Array(selected),
                                                 severity: severity, duringExercise: duringExercise)
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
