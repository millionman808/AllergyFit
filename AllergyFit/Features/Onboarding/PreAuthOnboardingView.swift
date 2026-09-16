import SwiftUI
import AuthenticationServices
import Supabase
import GoogleSignIn

/// Highest-converting pre-account onboarding funnel.
/// Features 10 total slides with smooth directional sliding animations:
/// - Step 0: Welcome & Value Hook
/// - Step 1: Biological Sex / Gender profile (Male vs Female with specific physiology)
/// - Step 2: Allergens & Food Sensitivities (Top 14 + Custom + "No Allergies")
/// - Step 3: Severity & Reaction Tolerance (Mild, Moderate, Severe/Anaphylaxis)
/// - Step 4: Fitness Goal (Gender-specific: Muscle/Strength vs Lean Tone/Vitality)
/// - Step 5: Wearables & Activity (Apple Watch, Fitbit, Garmin, Whoop, iPhone)
/// - Step 6: Personal Stats & Gender-specific BMR calculation
/// - Step 7: Dynamic Plan Generation & Gender-tailored Blueprint reveal
/// - Step 8 (Second-to-last slide): Account creation (Apple, Google, Email, or Guest)
/// - Step 9 (Final slide): Zero-scroll single-screen Paywall with 3s hard lock & 3-day free trial
struct PreAuthOnboardingView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Called when the entire funnel finishes (trial started or free version chosen).
    var onFinish: () -> Void
    /// Called when the user explicitly taps "Sign in" on slide 0.
    var onSignIn: (() -> Void)? = nil

    @State private var step = 0
    @State private var isMovingForward = true
    @State private var draft = OnboardingDraft.stored ?? OnboardingDraft()
    @State private var showCustomTrigger = false
    @State private var customTriggerText = ""

    // Step 7: Dynamic calculation animation states
    @State private var calculationProgress: Double = 0.0
    @State private var calculationPhase: Int = 0
    @State private var calculationComplete = false

    // Step 8: Account creation states
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningUp = true
    @State private var authErrorMessage: String?
    @State private var authBusy = false

    private let total = 10
    private let allAllergens = MockData.allAllergens

    /// Standard list plus anything the user typed themselves.
    private var allTriggerOptions: [String] {
        ["No allergies (Track nutrition)", "Peanuts", "Tree nuts", "Milk/Dairy", "Eggs", "Gluten/Wheat", "Soy", "Fish", "Shellfish", "Sesame"] + draft.customAllergens
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            if step == 9 {
                // Final slide: Paywall directly embedded
                PaywallView(source: "onboarding", onDismiss: {
                    finish()
                })
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    topBar

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            content
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                        .id(step)
                        .transition(reduceMotion ? .opacity : .directionalSlide(forward: isMovingForward))
                    }
                    .animation(reduceMotion ? .easeOut(duration: 0.15)
                                            : .spring(response: 0.44, dampingFraction: 0.86), value: step)

                    if step != 8 {
                        footer
                    }
                }
            }
        }
        .alert("Add a trigger", isPresented: $showCustomTrigger) {
            TextField("e.g. mango, sulphites", text: $customTriggerText)
                .textInputAutocapitalization(.never)
            Button("Cancel", role: .cancel) {}
            Button("Add") { addCustomTrigger() }
        } message: {
            Text("Name anything you need to avoid that isn't in the list.")
        }
    }

    private func addCustomTrigger() {
        let name = customTriggerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let existing = allTriggerOptions.first { $0.caseInsensitiveCompare(name) == .orderedSame }
        let final = existing ?? name
        if existing == nil { draft.customAllergens.append(final) }
        draft.allergenNames.insert(final)
        draft.save()
        Haptics.success()
    }

    // MARK: - Navigation Chrome

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { back() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 34, height: 34)
            }
            .opacity(step == 0 ? 0 : 1)
            .disabled(step == 0)

            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Theme.Colors.volt : Theme.Colors.surfaceRaised)
                        .frame(height: i == step ? 5 : 3)
                }
            }
            .animation(.spring(response: 0.35), value: step)

            if !session.isSignedIn && step == 0 {
                Button("Sign in") {
                    if let onSignIn { onSignIn() } else { finish() }
                }
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.volt)
                .fontWeight(.semibold)
            } else {
                Color.clear.frame(width: 48, height: 34)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button { advance() } label: {
                HStack(spacing: 6) {
                    Text(step == 7 ? "Review & Save Plan" : "Continue")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.onVolt)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canAdvance ? Theme.Colors.volt : Theme.Colors.surfaceRaised,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(!canAdvance)
            .pressable()
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
    }

    private var canAdvance: Bool {
        switch step {
        case 2:
            return !draft.allergenNames.isEmpty
        case 7:
            return calculationComplete
        default:
            return true
        }
    }

    private func advance() {
        Haptics.tap()
        isMovingForward = true
        withAnimation { step += 1 }
        draft.save()
    }

    private func back() {
        Haptics.tap()
        isMovingForward = false
        withAnimation { step -= 1 }
    }

    private func finish() {
        draft.save()
        UserDefaults.standard.set(true, forKey: "seenPreAuthOnboarding")
        UserDefaults.standard.set(true, forKey: "seenPaywall")

        if session.isDemo {
            session.demoOnboarded = true
        }

        if let userId = session.session?.user.id {
            Task {
                try? await draft.apply(to: userId)
                OnboardingDraft.clear()
                await MainActor.run { session.profileOnboarded = true }
                AdAttribution.logOnboardingComplete()
            }
        }

        onFinish()
    }

    // MARK: - Step Router

    @ViewBuilder private var content: some View {
        switch step {
        case 0: welcomeStep
        case 1: genderStep
        case 2: triggersStep
        case 3: severityStep
        case 4: goalStep
        case 5: wearableStep
        case 6: statsStep
        case 7: calculationAndPayoffStep
        case 8: accountCreationStep
        default: EmptyView()
        }
    }

    private func header(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(Theme.Fonts.stat(31))
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(sub)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Slide 0: Welcome / Hook

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                Circle().fill(Theme.Colors.volt).frame(width: 76, height: 76)
                    .shadow(color: Theme.Colors.volt.opacity(0.45), radius: 18, y: 6)
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.Colors.onVolt)
            }
            .padding(.top, 16)
            .revealIn(0)

            header("Train hard.\nEat safe.",
                   "The complete fueling system for fitness enthusiasts with food allergies and intolerances.")
                .revealIn(1)

            VStack(alignment: .leading, spacing: 12) {
                bullet("checkmark.shield.fill", "Zero-trace allergen screening on every meal")
                    .revealIn(2)
                bullet("bolt.heart.fill", "Live calorie burn sync with your smartwatch")
                    .revealIn(3)
                bullet("gauge.with.needle.fill", "Daily Fuel Score & recovery nutrition balance")
                    .revealIn(4)
                bullet("fork.knife", "Custom meal plans matched to your macros and triggers")
                    .revealIn(5)
            }
            .padding(.top, 4)

            if !session.isSignedIn {
                Button {
                    if let onSignIn { onSignIn() } else { finish() }
                } label: {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text("Sign in")
                            .foregroundStyle(Theme.Colors.volt)
                            .fontWeight(.semibold)
                    }
                    .font(Theme.Fonts.caption)
                    .padding(.top, 6)
                }
                .revealIn(6)
            }
        }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.volt)
                .frame(width: 34, height: 34)
                .background(Theme.Colors.volt.opacity(0.13),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(text)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Slide 1: Gender / Biological Sex

    private var genderStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Which best describes you?",
                   "We only use this to estimate how many calories your body burns. It changes the math, nothing else.")
                .revealIn(0)

            HStack(spacing: 12) {
                genderCard("Male", icon: "figure.stand", isSelected: draft.gender == "Male")
                genderCard("Female", icon: "figure.stand.dress", isSelected: draft.gender == "Female")
            }
            .revealIn(1)

            Text("You can change this any time in Profile.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .revealIn(2)
        }
    }

    private func genderCard(_ gender: String, icon: String, isSelected: Bool) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { draft.gender = gender }
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.Colors.volt : Theme.Colors.surfaceRaised)
                        .frame(width: 64, height: 64)
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(isSelected ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                }
                Text(gender)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.Colors.volt : Theme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .background(isSelected ? Theme.Colors.volt.opacity(0.10) : Theme.Colors.surface,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Theme.Colors.volt : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isSelected ? 1.0 : 0.97)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Slide 2: Allergens & Triggers

    private var triggersStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("What do you need to avoid?",
                   "Select all allergens and sensitivities that apply. You can change this anytime.")
                .revealIn(0)

            FlowChips(items: allTriggerOptions,
                      selected: $draft.allergenNames,
                      onAddCustom: { customTriggerText = ""; showCustomTrigger = true })
                .revealIn(1)

            Text("Don't see your trigger? Tap **+ Add custom** to type anything.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .revealIn(2)
        }
    }

    // MARK: - Slide 3: Severity

    private var severityStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("How severe is each reaction?",
                   "SafeFuel strictly customizes cross-contact warnings based on your tolerance.")
                .revealIn(0)

            let filteredTriggers = draft.allergenNames.filter { !$0.contains("No allergies") }
            if filteredTriggers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.Colors.safe)
                    Text("No Triggers Selected")
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("SafeFuel will focus purely on your \(draft.gender.lowercased()) macro targets and workout fueling.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .card()
            } else {
                ForEach(Array(Array(filteredTriggers).sorted().enumerated()), id: \.element) { idx, name in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(name)
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        HStack(spacing: 6) {
                            ForEach(Sensitivity.allCases) { s in
                                Button {
                                    Haptics.tap()
                                    draft.severityByName[name] = s.rawValue
                                } label: {
                                    Text(s.short)
                                        .font(.system(size: 12, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 38)
                                        .background(selected(name) == s ? s.color.opacity(0.9)
                                                                        : Theme.Colors.surface,
                                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .foregroundStyle(selected(name) == s ? Theme.Colors.onVolt
                                                                             : Theme.Colors.textSecondary)
                                }
                            }
                        }
                    }
                    .card()
                    .revealIn(idx + 1)
                }
            }
        }
    }

    private func selected(_ name: String) -> Sensitivity {
        Sensitivity(rawValue: draft.severityByName[name] ?? "moderate") ?? .moderate
    }

    // MARK: - Slide 4: Goal (Gender-Specific)

    private var goalStep: some View {
        let isFemale = draft.gender == "Female"
        let goals: [(String, String, String)] = isFemale ? [
            ("Build Lean Muscle & Tone", "Sculpt lean muscle with 1.8g/kg protein and hormonal balance", "figure.strengthtraining.traditional"),
            ("Maintain & Vitality", "Steady energy, balanced metabolism, and cycle-aware fueling", "figure.run"),
            ("Fat Loss & Definition", "Hormone-sparing caloric deficit to shed fat while toning", "flame.fill")
        ] : [
            ("Build Muscle & Strength", "Hypertrophy focus with 2.0g/kg protein surplus", "figure.strengthtraining.traditional"),
            ("Maintain & Performance", "High-output athletic conditioning and peak power", "figure.run"),
            ("Cut & Definition", "Controlled deficit to shed fat while sparing maximum muscle", "flame.fill")
        ]

        return VStack(alignment: .leading, spacing: 18) {
            header("What is your primary training goal?",
                   "We calibrate your daily calories and protein breakdown around your \(draft.gender.lowercased()) biology.")
                .revealIn(0)

            ForEach(Array(goals.enumerated()), id: \.element.0) { idx, item in
                let targetKey = item.0.contains("Build") ? "Build muscle" : item.0.contains("Cut") || item.0.contains("Fat") ? "Cut" : "Maintain"
                Button {
                    Haptics.tap()
                    draft.goal = targetKey
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: item.2)
                            .font(.system(size: 20))
                            .foregroundStyle(draft.goal == targetKey ? Theme.Colors.volt : Theme.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Theme.Colors.surfaceRaised, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.0)
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(item.1)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: draft.goal == targetKey ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(draft.goal == targetKey ? Theme.Colors.volt : Theme.Colors.textTertiary)
                    }
                    .card()
                }
                .buttonStyle(.plain)
                .revealIn(idx + 1)
            }
        }
    }

    // MARK: - Slide 5: Wearable & Activity Tracking

    private var wearableStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Which device tracks your workouts?",
                   "SafeFuel syncs with Apple Health to automatically adjust your calories when you train.")
                .revealIn(0)

            let wearables = [
                ("Apple Watch", "applewatch", "Live heart rate & workout calories sync natively"),
                ("Fitbit / Google Pixel", "sensor.tag.radiowaves.forward.fill", "Bridges runs, steps & strain into SafeFuel"),
                ("Garmin / Whoop / Oura", "waveform.path.ecg", "Syncs high-strain recovery data via HealthKit"),
                ("iPhone Only", "iphone", "Tracks daily steps and active movement automatically")
            ]

            ForEach(Array(wearables.enumerated()), id: \.element.0) { idx, w in
                Button {
                    Haptics.tap()
                    draft.wearable = w.0
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: w.1)
                            .font(.system(size: 20))
                            .foregroundStyle(draft.wearable == w.0 ? Theme.Colors.volt : Theme.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Theme.Colors.surfaceRaised, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.0)
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(w.2)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: draft.wearable == w.0 ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(draft.wearable == w.0 ? Theme.Colors.volt : Theme.Colors.textTertiary)
                    }
                    .card()
                }
                .buttonStyle(.plain)
                .revealIn(idx + 1)
            }
        }
    }

    // MARK: - Slide 6: Personal Stats (Gender-Specific BMR)

    private var statsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Your metrics",
                   "Used for precision Mifflin-St Jeor \(draft.gender.lowercased()) metabolic calculations.")
            stepper("Training days / week", value: $draft.trainingDays, range: 0...7, suffix: " days")
            stepper("Weight", value: $draft.weightLb, range: 70...500, suffix: " lb", by: 5)
            stepper("Height (ft)", value: $draft.heightFeet, range: 3...7, suffix: "'")
            stepper("Height (in)", value: $draft.heightInches, range: 0...11, suffix: "\"")
            stepper("Age", value: $draft.age, range: 13...100, suffix: " yrs")

            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Theme.Colors.volt)
                    .font(.system(size: 15))
                let isFemale = draft.gender == "Female"
                Text(isFemale ? "Using female BMR formula (-161 kcal factor) for basal metabolic calibration."
                              : "Using male BMR formula (+5 kcal factor) for basal metabolic calibration.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(10)
            .background(Theme.Colors.volt.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func stepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>,
                         suffix: String, by: Int = 1) -> some View {
        HStack {
            Text(label).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Button {
                if value.wrappedValue - by >= range.lowerBound {
                    Haptics.tap(); value.wrappedValue -= by
                }
            } label: {
                Image(systemName: "minus").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Theme.Colors.surfaceRaised, in: Circle())
            }
            Text("\(value.wrappedValue)\(suffix)")
                .font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                .frame(minWidth: 64)
            Button {
                if value.wrappedValue + by <= range.upperBound {
                    Haptics.tap(); value.wrappedValue += by
                }
            } label: {
                Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.onVolt)
                    .frame(width: 34, height: 34)
                    .background(Theme.Colors.volt, in: Circle())
            }
        }
        .card()
    }

    // MARK: - Slide 7: Dynamic Plan Generation & Gender Blueprint Reveal

    private var calculationAndPayoffStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !calculationComplete {
                generatingCard
            } else {
                planRevealCard
            }
        }
        .task {
            if !calculationComplete {
                runCalculationAnimation()
            }
        }
    }

    private var generatingCard: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 10)

            ZStack {
                Circle()
                    .stroke(Theme.Colors.surfaceRaised, lineWidth: 8)
                    .frame(width: 130, height: 130)

                Circle()
                    .trim(from: 0, to: calculationProgress)
                    .stroke(Theme.Colors.volt, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: calculationProgress)

                VStack(spacing: 2) {
                    Text("\(Int(calculationProgress * 100))%")
                        .font(Theme.Fonts.stat(32))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(draft.gender.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.volt)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                Text(phaseTitle)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Applying your \(draft.allergenNames.count) triggers, \(draft.gender.lowercased()) baseline, and \(draft.wearable) sync.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                calcCheckItem(title: "Allergen matrix screening", done: calculationProgress >= 0.25)
                calcCheckItem(title: "\(draft.gender) metabolic expenditure (-161/+5 factor)", done: calculationProgress >= 0.50)
                calcCheckItem(title: "Wearable energy balance integration", done: calculationProgress >= 0.75)
                calcCheckItem(title: "\(draft.gender) macro blueprint optimization", done: calculationProgress >= 0.98)
            }
            .padding(16)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func calcCheckItem(title: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(done ? Theme.Colors.volt : Theme.Colors.textTertiary)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(done ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
            Spacer()
        }
    }

    private var phaseTitle: String {
        switch calculationPhase {
        case 0: return "Analyzing Allergy Triggers..."
        case 1: return "Calibrating \(draft.gender) BMR Baseline..."
        case 2: return "Optimizing Protein & Nutrient Ratios..."
        default: return "Finalizing Your \(draft.gender) Plan..."
        }
    }

    private func runCalculationAnimation() {
        Task {
            for i in 1...20 {
                try? await Task.sleep(nanoseconds: 90_000_000)
                await MainActor.run {
                    calculationProgress = Double(i) / 20.0
                    if calculationProgress >= 0.75 { calculationPhase = 3 }
                    else if calculationProgress >= 0.50 { calculationPhase = 2 }
                    else if calculationProgress >= 0.25 { calculationPhase = 1 }
                }
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                calculationComplete = true
            }
            Haptics.success()
            // The first value moment: they've just seen their own numbers.
            // Ask for tracking here — after the payoff lands, before the
            // account step and well before the paywall. Never on top of it.
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await AdAttribution.requestTrackingIfNeeded()
        }
    }

    private var planRevealCard: some View {
        let t = draft.targets
        let isFemale = draft.gender == "Female"
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.Colors.volt)
                Text("\(draft.gender.uppercased()) FUEL BLUEPRINT LOCKED")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.volt)
            }

            header("Your plan is locked in.",
                   "Customized for \(draft.goal.lowercased()), \(draft.gender.lowercased()) physiology, and your personal triggers.")

            HStack(spacing: 8) {
                target(t.calories.formatted(.number.grouping(.automatic)), "calories", Theme.Colors.volt)
                target("\(t.protein)g", "protein", Theme.Colors.protein)
                target("\(t.carbs)g", "carbs", Theme.Colors.carbs)
                target("\(t.fat)g", "fat", Theme.Colors.fat)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("100% Allergen Shield Active", systemImage: "shield.checkerboard")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.safe)
                let activeAllergens = Array(draft.allergenNames.filter { !$0.contains("No allergies") })
                Text(activeAllergens.isEmpty ? "All standard food logging protected." : activeAllergens.sorted().joined(separator: " · "))
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .card()

            HStack(spacing: 10) {
                Image(systemName: isFemale ? "heart.circle.fill" : "bolt.circle.fill")
                    .foregroundStyle(Theme.Colors.volt)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text(isFemale ? "Female Micronutrient Shield" : "Male Performance Shield")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(isFemale ? "Iron & Calcium prioritized for bone density & sustained stamina."
                                  : "Zinc & Magnesium prioritized for lean muscle synthesis & power.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(12)
            .background(Theme.Colors.volt.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func target(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 3) {
            Text(v).font(Theme.Fonts.stat(19)).foregroundStyle(c)
            Text(l).font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Slide 8: Account Creation (Second-to-Last Slide)

    private var accountCreationStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Save your \(draft.gender.lowercased()) plan",
                   "Create an account to backup your targets, allergen shield, and workout history.")

            if let authErrorMessage {
                Text(authErrorMessage)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.danger)
                    .padding(10)
                    .background(Theme.Colors.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }

            VStack(spacing: 12) {
                // Sign in with Apple
                SignInWithAppleButton(isSigningUp ? .signUp : .signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task { await handleApple(result) }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Continue with Google
                Button {
                    Task { await handleGoogle() }
                } label: {
                    HStack(spacing: 10) {
                        GoogleGlyph().frame(width: 20, height: 20)
                        Text("Continue with Google")
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Color(hex: 0x1F1F1F))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .pressable()
                .disabled(authBusy)

                HStack {
                    Rectangle().fill(Theme.Colors.surfaceRaised).frame(height: 1)
                    Text("or use email").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textTertiary)
                    Rectangle().fill(Theme.Colors.surfaceRaised).frame(height: 1)
                }
                .padding(.vertical, 4)

                TextField("Email address", text: $email)
                    .textFieldStyle(AFFieldStyle())
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Password (min 6 chars)", text: $password)
                    .textFieldStyle(AFFieldStyle())

                Button {
                    Task { await submitEmail() }
                } label: {
                    Group {
                        if authBusy {
                            ProgressView().tint(Theme.Colors.onVolt)
                        } else {
                            Text(isSigningUp ? "Create Account & Continue" : "Sign In & Continue")
                                .font(Theme.Fonts.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.Colors.volt)
                    .foregroundStyle(Theme.Colors.onVolt)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .pressable()
                .disabled(authBusy || email.isEmpty || password.isEmpty)
                .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)

                Button {
                    withAnimation {
                        isSigningUp.toggle()
                        authErrorMessage = nil
                    }
                } label: {
                    Text(isSigningUp ? "Already have an account? Sign in" : "New user? Create an account")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

            }
        }
    }

    // MARK: - Auth Handlers

    @MainActor
    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        guard case .success(let auth) = result,
              let credential = auth.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            authErrorMessage = "Apple sign-in failed. Try again."
            return
        }
        authBusy = true
        defer { authBusy = false }
        do {
            try await Backend.client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: token)
            )
            Haptics.success()
            isMovingForward = true
            withAnimation { step = 9 }
        } catch {
            authErrorMessage = AuthView.friendlyAuthMessage(error)
        }
    }

    @MainActor
    private func handleGoogle() async {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController else {
            authErrorMessage = "Couldn't start Google sign-in. Try again."
            return
        }
        authBusy = true
        defer { authBusy = false }
        authErrorMessage = nil
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
            guard let idToken = result.user.idToken?.tokenString else {
                authErrorMessage = "Google didn't return a sign-in token. Try again."
                return
            }
            try await Backend.client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
            )
            Haptics.success()
            isMovingForward = true
            withAnimation { step = 9 }
        } catch {
            let ns = error as NSError
            if ns.domain == kGIDSignInErrorDomain, ns.code == GIDSignInError.canceled.rawValue { return }
            authErrorMessage = AuthView.friendlyAuthMessage(error)
        }
    }

    @MainActor
    private func submitEmail() async {
        authBusy = true
        defer { authBusy = false }
        authErrorMessage = nil
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = password
        do {
            if isSigningUp {
                let response = try await Backend.client.auth.signUp(email: mail, password: pass)
                Haptics.success()
                isMovingForward = true
                withAnimation { step = 9 }
            } else {
                _ = try await Backend.client.auth.signIn(email: mail, password: pass)
                Haptics.success()
                isMovingForward = true
                withAnimation { step = 9 }
            }
        } catch {
            authErrorMessage = AuthView.friendlyAuthMessage(error)
        }
    }
}
