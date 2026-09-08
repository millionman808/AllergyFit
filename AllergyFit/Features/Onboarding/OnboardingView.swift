import SwiftUI

/// 4-step onboarding: allergens → goal → stats → targets reveal.
struct OnboardingView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = min(max(UserDefaults.standard.integer(forKey: "onboardingStep"), 0), 3)
    @State private var movingForward = true
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
                onboardingChrome
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.top, 8)

                ZStack {
                    currentStep
                        .id(step)
                        .transition(stepTransition)
                }
                .clipped()
                .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.52, dampingFraction: 0.88), value: step)

                nextButton
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.bottom, 16)
            }
        }
        .onChange(of: step) { newValue in
            UserDefaults.standard.set(newValue, forKey: "onboardingStep")
        }
    }

    // MARK: - Chrome

    private var onboardingChrome: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(Theme.Colors.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .opacity(step == 0 ? 0 : 1)
                .disabled(step == 0)
                .accessibilityLabel("Previous step")

                Spacer()

                Text("SETUP  \(step + 1) OF \(totalSteps)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Theme.Colors.textTertiary)

                Spacer()

                Color.clear.frame(width: 34, height: 34)
            }

            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Theme.Colors.volt : Theme.Colors.surfaceRaised)
                        .frame(height: i == step ? 5 : 3)
                        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.72), value: step)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step + 1) of \(totalSteps)")
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
                    advance()
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
            .pressable()
        }
    }

    @ViewBuilder private var currentStep: some View {
        switch step {
        case 1: goalStep
        case 2: statsStep
        case 3: targetsStep
        default: allergenStep
        }
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: movingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func advance() {
        guard step < totalSteps - 1 else { return }
        Haptics.tap()
        movingForward = true
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.52, dampingFraction: 0.88)) {
            step += 1
        }
    }

    private func goBack() {
        guard step > 0 else { return }
        Haptics.tap()
        movingForward = false
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.52, dampingFraction: 0.88)) {
            step -= 1
        }
    }

    // MARK: - Finish: persist profile + allergens for real accounts

    private func finish() {
        if session.isDemo {
            UserDefaults.standard.removeObject(forKey: "onboardingStep")
            Haptics.success()
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.5, dampingFraction: 0.86)) {
                session.demoOnboarded = true
            }
            return
        }
        guard let userId = session.session?.user.id else { return }
        isSaving = true
        saveError = nil
        Task {
            do {
                try await saveProfile(userId: userId)
                await session.reloadAllergens(userId: userId)
                UserDefaults.standard.removeObject(forKey: "onboardingStep")
                Haptics.success()
                withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.5, dampingFraction: 0.86)) {
                    session.profileOnboarded = true
                }
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
                OnboardingMotionHero(step: 0)
                    .onboardingReveal(delay: 0.02)
                header("What should we\nkeep off your plate?", "Select everything you react to. Safety first — every meal is filtered against this list.")
                    .onboardingReveal(delay: 0.08)
                FlowChips(items: MockData.allAllergens, selected: $selectedAllergens)
                    .onboardingReveal(delay: 0.15)
                Button {
                } label: {
                    Label("Add a custom trigger", systemImage: "plus.circle.fill")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.volt)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onboardingReveal(delay: 0.22)
            }
            .padding(Theme.Metrics.screenPadding)
        }
    }

    // MARK: - Step 2: Goal

    private var goalStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                OnboardingMotionHero(step: 1)
                    .onboardingReveal(delay: 0.02)
                header("What's the mission?", "Your meal plan flexes around this.")
                    .onboardingReveal(delay: 0.08)
                VStack(spacing: Theme.Metrics.spacing) {
                    goalCard("Cut", "Lose fat, keep muscle", "flame.fill", "Cut")
                    goalCard("Build muscle", "Fuel growth around your triggers", "dumbbell.fill", "Build muscle")
                    goalCard("Maintain", "Stay strong with a steady plan", "scalemass.fill", "Maintain")
                }
                .onboardingReveal(delay: 0.15)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Training days per week")
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { d in
                            Button {
                                Haptics.tap()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.68)) {
                                    trainingDays = d
                                }
                            } label: {
                                Text("\(d)")
                                    .font(Theme.Fonts.stat(16))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(trainingDays == d ? Theme.Colors.volt : Theme.Colors.surface)
                                    .foregroundStyle(trainingDays == d ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .scaleEffect(trainingDays == d ? 1.06 : 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .card()
                .onboardingReveal(delay: 0.22)
            }
            .padding(Theme.Metrics.screenPadding)
        }
    }

    private func goalCard(_ title: String, _ subtitle: String, _ icon: String, _ value: String) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) {
                goal = value
            }
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
            .scaleEffect(goal == value ? 1 : 0.985)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Stats

    private var statsStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                OnboardingMotionHero(step: 2)
                    .onboardingReveal(delay: 0.02)
                header("Dial in the numbers", "We use these to calculate your daily targets.")
                    .onboardingReveal(delay: 0.08)
                VStack(spacing: Theme.Metrics.spacing) {
                    stepperRow("Weight", "\(weight) lb") { weight = max(80, weight - 5) } up: { weight = min(400, weight + 5) }
                    stepperRow("Height", "\(heightFeet)′ \(heightInches)″") {
                        if heightInches == 0 { heightFeet -= 1; heightInches = 11 } else { heightInches -= 1 }
                    } up: {
                        if heightInches == 11 { heightFeet += 1; heightInches = 0 } else { heightInches += 1 }
                    }
                    stepperRow("Age", "\(age)") { age = max(13, age - 1) } up: { age = min(90, age + 1) }
                }
                .onboardingReveal(delay: 0.15)
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
            Button {
                Haptics.tap()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { down() }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.surfaceRaised, Theme.Colors.textSecondary)
            }
            Text(value)
                .font(Theme.Fonts.stat(24))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(minWidth: 110)
                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: value)
            Button {
                Haptics.tap()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { up() }
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.volt)
                        .frame(width: 28, height: 28)
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Theme.Colors.onVolt)
                }
            }
        }
        .card()
    }

    // MARK: - Step 4: Targets reveal

    private var targetsStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                OnboardingMotionHero(step: 3)
                    .onboardingReveal(delay: 0.02)
                header("Your daily fuel plan", "Auto-adjusted on training days. Every meal filtered against \(selectedAllergens.count) triggers.")
                    .onboardingReveal(delay: 0.08)

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
                .onboardingReveal(delay: 0.15)

                HStack(spacing: Theme.Metrics.spacing) {
                    targetPill("Protein", "\(t.protein)g", Theme.Colors.protein)
                    targetPill("Carbs", "\(t.carbs)g", Theme.Colors.carbs)
                    targetPill("Fat", "\(t.fat)g", Theme.Colors.fat)
                }
                .onboardingReveal(delay: 0.23)

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
                .onboardingReveal(delay: 0.31)
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
                    Haptics.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.68)) {
                        if isOn { selected.remove(item) } else { selected.insert(item) }
                    }
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
                        .scaleEffect(isOn ? 1.03 : 1)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Onboarding motion language

/// One continuous visual motif across setup: personal data passes through a
/// protective orbit and resolves as a safe plan on the final step.
private struct OnboardingMotionHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let step: Int
    @State private var orbiting = false
    @State private var pulsing = false

    private let symbols = ["fork.knife", "figure.strengthtraining.traditional", "slider.horizontal.3", "checkmark.shield.fill"]
    private let labels = ["FILTER", "FUEL", "TUNE", "READY"]

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.volt.opacity(0.10), lineWidth: 18)
                .frame(width: 106, height: 106)
                .scaleEffect(pulsing ? 1.12 : 0.92)
                .opacity(pulsing ? 0.15 : 0.7)

            Circle()
                .trim(from: 0.06, to: 0.78)
                .stroke(
                    Theme.Colors.volt.opacity(0.72),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 9])
                )
                .frame(width: 106, height: 106)
                .rotationEffect(.degrees(orbiting ? 360 : 0))

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == step % 3 ? Theme.Colors.volt : Theme.Colors.textTertiary.opacity(0.55))
                    .frame(width: index == step % 3 ? 8 : 5, height: index == step % 3 ? 8 : 5)
                    .offset(y: -53)
                    .rotationEffect(.degrees(Double(index) * 120 + (orbiting ? 360 : 0)))
            }

            Circle()
                .fill(Theme.Colors.surface)
                .frame(width: 76, height: 76)
                .overlay(Circle().stroke(Theme.Colors.volt.opacity(0.22), lineWidth: 1))
                .shadow(color: Theme.Colors.volt.opacity(0.16), radius: 18, y: 8)

            VStack(spacing: 4) {
                Image(systemName: symbols[step])
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.Colors.volt)
                Text(labels[step])
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .frame(height: 128)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                orbiting = true
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

private struct OnboardingRevealModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (isVisible ? 0 : 18))
            .scaleEffect(reduceMotion ? 1 : (isVisible ? 1 : 0.985), anchor: .top)
            .onAppear {
                if reduceMotion {
                    isVisible = true
                } else {
                    withAnimation(.spring(response: 0.56, dampingFraction: 0.84).delay(delay)) {
                        isVisible = true
                    }
                }
            }
    }
}

private extension View {
    func onboardingReveal(delay: Double) -> some View {
        modifier(OnboardingRevealModifier(delay: delay))
    }
}
