import SwiftUI

/// 4-step onboarding: allergens → goal → stats → targets reveal.
struct OnboardingView: View {
    @EnvironmentObject var session: SessionStore
    @State private var step = UserDefaults.standard.integer(forKey: "onboardingStep")
    @State private var selectedAllergens: Set<String> = ["Peanut", "Milk / Dairy", "Sesame"]
    @State private var goal = "Build muscle"
    @State private var trainingDays = 4
    @State private var weight = 175
    @State private var heightFeet = 5
    @State private var heightInches = 10
    @State private var age = 25
    @State private var isSaving = false
    @State private var saveError: String?

    private let totalSteps = 4

    /// Display name → allergens.slug (must match the seeded allergens table).
    static let slugByName: [String: String] = [
        "Peanut": "peanut", "Tree Nuts": "tree_nut", "Milk / Dairy": "dairy",
        "Egg": "egg", "Wheat": "wheat", "Gluten": "gluten", "Soy": "soy",
        "Fish": "fish", "Shellfish": "shellfish", "Sesame": "sesame",
        "Corn": "corn", "Nightshades": "nightshade", "Histamine": "histamine",
        "FODMAPs": "fodmap", "Sulfites": "sulfite", "Mustard": "mustard",
        "Alpha-gal": "alpha_gal",
    ]

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.top, 12)

                TabView(selection: $step) {
                    allergenStep.tag(0)
                    goalStep.tag(1)
                    statsStep.tag(2)
                    targetsStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)

                nextButton
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Chrome

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Theme.Colors.volt : Theme.Colors.surfaceRaised)
                    .frame(height: 4)
            }
        }
    }

    private var nextButton: some View {
        VStack(spacing: 6) {
            if let saveError {
                Text(saveError)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.danger)
            }
            Button {
                if step < totalSteps - 1 {
                    withAnimation { step += 1 }
                } else {
                    finish()
                }
            } label: {
                Group {
                    if isSaving {
                        ProgressView().tint(Theme.Colors.onVolt)
                    } else {
                        Text(step == totalSteps - 1 ? "Start Training" : "Continue")
                            .font(Theme.Fonts.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Theme.Colors.volt)
                .foregroundStyle(Theme.Colors.onVolt)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(isSaving)
        }
    }

    // MARK: - Finish: persist profile + allergens for real accounts

    private func finish() {
        if session.isDemo {
            withAnimation { session.demoOnboarded = true }
            return
        }
        guard let userId = session.session?.user.id else { return }
        isSaving = true
        saveError = nil
        Task {
            do {
                try await saveProfile(userId: userId)
                await session.reloadAllergens(userId: userId)
                withAnimation { session.profileOnboarded = true }
            } catch {
                saveError = "Couldn't save: \(error.localizedDescription)"
            }
            isSaving = false
        }
    }

    private var targets: (calories: Int, protein: Int, carbs: Int, fat: Int) {
        let kg = Double(weight) * 0.4536
        let cm = (Double(heightFeet) * 12 + Double(heightInches)) * 2.54
        // Mifflin-St Jeor, sex-neutral midpoint constant
        let bmr = 10 * kg + 6.25 * cm - 5 * Double(age) - 78
        let activity: Double = trainingDays <= 1 ? 1.375 : trainingDays <= 3 ? 1.5 : trainingDays <= 5 ? 1.65 : 1.75
        var calories = bmr * activity
        switch goal {
        case "Cut": calories -= 400
        case "Build muscle": calories += 300
        default: break
        }
        let protein = Int((kg * 1.9).rounded())
        let fat = Int((kg * 0.9).rounded())
        let carbs = Int(((calories - Double(protein * 4) - Double(fat * 9)) / 4).rounded())
        return (Int(calories.rounded()), protein, max(carbs, 0), fat)
    }

    private func saveProfile(userId: UUID) async throws {
        let goalValue = goal == "Cut" ? "cut" : goal == "Build muscle" ? "build" : "maintain"
        let t = targets
        struct ProfileUpdate: Codable {
            let fitness_goal: String
            let birth_year: Int
            let height_cm: Double
            let weight_kg: Double
            let training_days_per_week: Int
            let target_calories: Int
            let target_protein_g: Int
            let target_carbs_g: Int
            let target_fat_g: Int
            let onboarding_completed: Bool
        }
        let update = ProfileUpdate(
            fitness_goal: goalValue,
            birth_year: Calendar.current.component(.year, from: Date()) - age,
            height_cm: (Double(heightFeet) * 12 + Double(heightInches)) * 2.54,
            weight_kg: Double(weight) * 0.4536,
            training_days_per_week: trainingDays,
            target_calories: t.calories,
            target_protein_g: t.protein,
            target_carbs_g: t.carbs,
            target_fat_g: t.fat,
            onboarding_completed: true
        )
        try await Backend.client.from("profiles").update(update)
            .eq("id", value: userId).execute()

        // allergens: resolve slugs → ids, then upsert selections
        struct ARow: Codable { let id: Int; let slug: String }
        let known: [ARow] = try await Backend.client
            .from("allergens").select("id, slug").execute().value
        let idBySlug = Dictionary(uniqueKeysWithValues: known.map { ($0.slug, $0.id) })
        struct UAInsert: Codable {
            let user_id: UUID
            let allergen_id: Int
            let severity: String
        }
        let rows = selectedAllergens
            .compactMap { Self.slugByName[$0].flatMap { idBySlug[$0] } }
            .map { UAInsert(user_id: userId, allergen_id: $0, severity: "moderate") }
        if !rows.isEmpty {
            try await Backend.client.from("user_allergens")
                .upsert(rows, onConflict: "user_id,allergen_id", ignoreDuplicates: true)
                .execute()
        }
    }

    private func header(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.Fonts.stat(30))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(subtitle)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Step 1: Allergens

    private var allergenStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                header("What should we\nkeep off your plate?", "Select everything you react to. Safety first — every meal is filtered against this list.")
                FlowChips(items: MockData.allAllergens, selected: $selectedAllergens)
                Button {
                } label: {
                    Label("Add a custom trigger", systemImage: "plus.circle.fill")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.volt)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Metrics.screenPadding)
        }
    }

    // MARK: - Step 2: Goal

    private var goalStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                header("What's the mission?", "Your meal plan flexes around this.")
                VStack(spacing: Theme.Metrics.spacing) {
                    goalCard("Cut", "Lose fat, keep muscle", "flame.fill", "Cut")
                    goalCard("Build muscle", "Fuel growth with safe surplus", "dumbbell.fill", "Build muscle")
                    goalCard("Maintain", "Stay strong, stay safe", "scalemass.fill", "Maintain")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Training days per week")
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { d in
                            Button {
                                trainingDays = d
                            } label: {
                                Text("\(d)")
                                    .font(Theme.Fonts.stat(16))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(trainingDays == d ? Theme.Colors.volt : Theme.Colors.surface)
                                    .foregroundStyle(trainingDays == d ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                }
                .card()
            }
            .padding(Theme.Metrics.screenPadding)
        }
    }

    private func goalCard(_ title: String, _ subtitle: String, _ icon: String, _ value: String) -> some View {
        Button {
            goal = value
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(goal == value ? Theme.Colors.onVolt : Theme.Colors.volt)
                    .frame(width: 44, height: 44)
                    .background(goal == value ? Theme.Colors.volt.opacity(0.9) : Theme.Colors.surfaceRaised, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(subtitle)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: goal == value ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(goal == value ? Theme.Colors.volt : Theme.Colors.textTertiary)
            }
            .padding(Theme.Metrics.cardPadding)
            .background(Theme.Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .stroke(goal == value ? Theme.Colors.volt : .clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
        }
    }

    // MARK: - Step 3: Stats

    private var statsStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                header("Dial in the numbers", "We use these to calculate your daily targets.")
                VStack(spacing: Theme.Metrics.spacing) {
                    stepperRow("Weight", "\(weight) lb") { weight = max(80, weight - 5) } up: { weight = min(400, weight + 5) }
                    stepperRow("Height", "\(heightFeet)′ \(heightInches)″") {
                        if heightInches == 0 { heightFeet -= 1; heightInches = 11 } else { heightInches -= 1 }
                    } up: {
                        if heightInches == 11 { heightFeet += 1; heightInches = 0 } else { heightInches += 1 }
                    }
                    stepperRow("Age", "\(age)") { age = max(13, age - 1) } up: { age = min(90, age + 1) }
                }
            }
            .padding(Theme.Metrics.screenPadding)
        }
    }

    private func stepperRow(_ label: String, _ value: String, down: @escaping () -> Void, up: @escaping () -> Void) -> some View {
        HStack {
            Text(label)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Button(action: down) {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.surfaceRaised, Theme.Colors.textSecondary)
            }
            Text(value)
                .font(Theme.Fonts.stat(24))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(minWidth: 110)
            Button(action: up) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.volt.opacity(0.25), Theme.Colors.volt)
            }
        }
        .card()
    }

    // MARK: - Step 4: Targets reveal

    private var targetsStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                header("Your daily fuel plan", "Auto-adjusted on training days. Every meal filtered against \(selectedAllergens.count) triggers.")

                let t = targets
                VStack(spacing: 4) {
                    Text("\(t.calories.formatted())")
                        .font(Theme.Fonts.stat(64))
                        .foregroundStyle(Theme.Colors.volt)
                    Text("calories on training days")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("\((t.calories - 300).formatted()) on rest days")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .card()

                HStack(spacing: Theme.Metrics.spacing) {
                    targetPill("Protein", "\(t.protein)g", Theme.Colors.protein)
                    targetPill("Carbs", "\(t.carbs)g", Theme.Colors.carbs)
                    targetPill("Fat", "\(t.fat)g", Theme.Colors.fat)
                }

                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(Theme.Colors.safe)
                    Text("Blocked: \(selectedAllergens.sorted().joined(separator: ", "))")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .card()
            }
            .padding(Theme.Metrics.screenPadding)
        }
    }

    private func targetPill(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.Fonts.stat(22))
                .foregroundStyle(color)
            Text(label)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}

// MARK: - Flowing chip grid

struct FlowChips: View {
    let items: [String]
    @Binding var selected: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isOn = selected.contains(item)
                Button {
                    if isOn { selected.remove(item) } else { selected.insert(item) }
                } label: {
                    Text(item)
                        .font(Theme.Fonts.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(isOn ? Theme.Colors.volt : Theme.Colors.surface)
                        .foregroundStyle(isOn ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(isOn ? .clear : Theme.Colors.surfaceRaised, lineWidth: 1))
                }
            }
        }
    }
}
