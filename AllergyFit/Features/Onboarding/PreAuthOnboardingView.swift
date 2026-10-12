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
/// Then the app's membership gate (RootView) shows the paywall.
struct PreAuthOnboardingView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Called when the entire funnel finishes (trial started or free version chosen).
    var onFinish: () -> Void
    /// Called when the user explicitly taps "Sign in" on slide 0.
    var onSignIn: (() -> Void)? = nil

    /// Screenshot/debug: launch with `-onboardingSlide 11` to open on a slide.
    @State private var step = UserDefaults.standard.integer(forKey: "onboardingSlide")
    @State private var isMovingForward = true
    @State private var draft = OnboardingDraft.stored ?? OnboardingDraft()
    @State private var showCustomTrigger = false
    @State private var customTriggerText = ""
    @State private var previousTriggers: Set<String> = []

    // Finch Plant-Your-Pit Hatch states
    @State private var pitTapCount: Int = UserDefaults.standard.integer(forKey: "debugPitTapCount")
    @State private var pitWobble: Double = 0.0

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

    /// Finch-inspired companion onboarding journey:
    /// Welcome (what the app does) -> Pick pot -> Plant & Hatch pit -> Name companion -> Gender ->
    /// Triggers -> Severity -> Goals -> Wearables -> Body stats ->
    /// Plan reveal -> Account save -> Paywall gate.
    enum Slide: Int, CaseIterable {
        case welcome, pickPot, plantAndHatch, namePip,
             gender, triggers, severity, goal, wearable, stats,
             plan, account
    }
    private var total: Int { Slide.allCases.count }
    private var slide: Slide { Slide(rawValue: step) ?? .welcome }
    private let allAllergens = MockData.allAllergens

    /// Standard list plus anything the user typed themselves.
    static let noTriggers = "Nothing — just track nutrition"
    static let maxNameLength = 14
    private var allTriggerOptions: [String] {
        [Self.noTriggers] + MockData.allAllergens + draft.customAllergens
    }

    var body: some View {
        ZStack {
            Club.Colors.background.ignoresSafeArea()

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

                if slide != .account {
                    footer
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
        .preferredColorScheme(.light)
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
                    .foregroundStyle(Club.Colors.textSecondary)
                    .frame(width: 34, height: 34)
            }
            .opacity(step == 0 ? 0 : 1)
            .disabled(step == 0)

            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Club.Colors.volt : Club.Colors.surfaceRaised)
                        .frame(height: i == step ? 5 : 3)
                }
            }
            .animation(.spring(response: 0.35), value: step)

            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var footerButtonText: String {
        switch slide {
        case .welcome: return "Get started"
        case .pickPot: return "Plant my pit"
        case .plantAndHatch: return pitTapCount >= 3 ? "Name your avocado" : "Tap the pit to hatch (\(max(0, 3 - pitTapCount)))"
        case .namePip: return "Nice to meet you, \(draft.companionName)!"
        case .plan: return "Save our plan"
        default: return "Continue"
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button { advance() } label: {
                HStack(spacing: 6) {
                    Text(footerButtonText)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .font(Club.Fonts.headline)
                .foregroundStyle(canAdvance ? Club.Colors.onVolt : Club.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canAdvance ? Club.Colors.volt : Club.Colors.surfaceRaised,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(!canAdvance)
            .pressable()

            if slide == .welcome && !session.isSignedIn {
                Button {
                    if let onSignIn { onSignIn() } else { finish() }
                } label: {
                    Text("I already have an account")
                        .font(Club.Fonts.headline)
                        .foregroundStyle(Club.Colors.volt)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
    }

    private var canAdvance: Bool {
        switch slide {
        case .plantAndHatch: return pitTapCount >= 3
        case .namePip: return !draft.companionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .triggers: return !draft.allergenNames.isEmpty
        case .goal:     return !(draft.goalPicks ?? []).isEmpty
        case .plan:     return calculationComplete
        default:        return true
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
        UserDefaults.standard.set(draft.companionName, forKey: "fuelFriendName")
        UserDefaults.standard.set(draft.chosenPot, forKey: "fuelFriendPot")

        if session.isDemo {
            session.demoOnboarded = true
        }

        if let userId = session.session?.user.id {
            session.profileOnboarded = true
            let draft = draft
            Task {
                if (try? await draft.apply(to: userId)) != nil { OnboardingDraft.clear() }
                AdAttribution.logOnboardingComplete()
            }
        }

        onFinish()
    }

    // MARK: - Step Router

    @ViewBuilder private var content: some View {
        switch step {
        case Slide.welcome.rawValue:       welcomeStep
        case Slide.pickPot.rawValue:       pickPotStep
        case Slide.plantAndHatch.rawValue: plantAndHatchStep
        case Slide.namePip.rawValue:       namePipStep
        case Slide.gender.rawValue:        genderStep
        case Slide.triggers.rawValue:      triggersStep
        case Slide.severity.rawValue:      severityStep
        case Slide.goal.rawValue:          goalStep
        case Slide.wearable.rawValue:      wearableStep
        case Slide.stats.rawValue:         statsStep
        case Slide.plan.rawValue:          calculationAndPayoffStep
        case Slide.account.rawValue:       accountCreationStep
        default: EmptyView()
        }
    }

    private func header(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(Club.Fonts.stat(31))
                .foregroundStyle(Club.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(sub)
                .font(Club.Fonts.body)
                .foregroundStyle(Club.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Welcome: what SafeFuel does, before the pet game starts

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Spacer()
                Image("pip_wave")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 210)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, y: 8)
                Spacer()
            }
            .revealIn(0)

            VStack(alignment: .leading, spacing: 8) {
                HighlightHeadline(text: "Eat well, feel good, and reach your goal.", highlight: "feel good", size: 32)
                Text("SafeFuel counts your calories, checks every meal against the foods that upset you, and helps you lose weight without the bloat.")
                    .font(Club.Fonts.body)
                    .foregroundStyle(Club.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .revealIn(1)

            VStack(alignment: .leading, spacing: 12) {
                welcomeRow("camera.fill", Club.Colors.pastelPeach, "Snap a meal", "Real calories from the USDA database, checked against your triggers.")
                welcomeRow("waveform.path.ecg", Club.Colors.pastelLavender, "Find your triggers", "See which foods keep showing up before a rough day.")
                welcomeRow("leaf.fill", Club.Colors.avocadoGreen, "Grow a little friend", "Small daily goals keep your avocado happy and earn rewards.")
            }
            .card()
            .revealIn(2)
        }
    }

    private func welcomeRow(_ icon: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Club.Fonts.headline).foregroundStyle(Club.Colors.textPrimary)
                Text(detail).font(Club.Fonts.caption).foregroundStyle(Club.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Slide 0: Pick Flower Pot

    private struct PotOption: Identifiable {
        let id: String
        let name: String
        let subtitle: String
    }

    private let potOptions: [PotOption] = [
        .init(id: "pot_1", name: "Terracotta", subtitle: "Warm Earth"),
        .init(id: "pot_2", name: "Sage Meadow", subtitle: "Soothing Leaf"),
        .init(id: "pot_3", name: "Buttercup", subtitle: "Golden Sun"),
        .init(id: "pot_4", name: "Blush Bloom", subtitle: "Cozy Petal"),
        .init(id: "pot_5", name: "Morning Sky", subtitle: "Pastel Breeze"),
        .init(id: "pot_6", name: "Cream Dotted", subtitle: "Speckled Linen")
    ]

    private var pickPotStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Windowsill Garden")
                    .font(Club.Fonts.clubTag(11)).tracking(1.8)
                    .foregroundStyle(Club.Colors.antiqueBrass)
                    .revealIn(0)
                HighlightHeadline(text: "Pick a pot for your friend.", highlight: "your friend.", size: 32)
                    .revealIn(0)
                Text("Every avocado journey starts in a cozy ceramic pot on your kitchen windowsill. Pick your favorite style:")
                    .font(Club.Fonts.body)
                    .foregroundStyle(Club.Colors.textSecondary)
                    .revealIn(1)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(potOptions) { pot in
                    let isSelected = draft.chosenPot == pot.id
                    Button {
                        Haptics.tap()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            draft.chosenPot = pot.id
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(pot.id)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 92)
                                .scaleEffect(isSelected ? 1.06 : 1.0)
                                .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.04), radius: 6, y: 3)

                            VStack(spacing: 2) {
                                Text(pot.name)
                                    .font(Club.Fonts.headline)
                                    .foregroundStyle(Club.Colors.textPrimary)
                                Text(pot.subtitle)
                                    .font(Club.Fonts.caption)
                                    .foregroundStyle(Club.Colors.textTertiary)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(isSelected ? Club.Colors.volt : Club.Colors.textTertiary)
                                Text(isSelected ? "Selected" : "Choose")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(isSelected ? Club.Colors.volt : Club.Colors.textTertiary)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity)
                        .background(Club.Colors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(isSelected ? Club.Colors.volt : Club.Colors.parchmentBorder, lineWidth: isSelected ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .revealIn(2)
        }
    }

    // MARK: - Slide 1: Plant & Tap-to-Hatch

    private var plantAndHatchStep: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(pitTapCount >= 3 ? "A New Friend Has Arrived!" : "Windowsill Garden")
                    .font(Club.Fonts.clubTag(11)).tracking(1.8)
                    .foregroundStyle(Club.Colors.antiqueBrass)
                HighlightHeadline(
                    text: pitTapCount >= 3 ? "Your avocado hatched!" : "Tap the pit to wake it up!",
                    highlight: pitTapCount >= 3 ? "hatched!" : "wake it up!",
                    size: 32
                )
                Text(
                    pitTapCount >= 3
                        ? "Say hello to your new friend! Next, give them a name."
                        : "Avocado seeds need gentle taps to sprout out of the soil. Tap the pit 3 times!"
                )
                .font(Club.Fonts.body)
                .foregroundStyle(Club.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .revealIn(0)

            // The Planter Stage
            ZStack {
                if pitTapCount >= 3 {
                    Circle()
                        .fill(RadialGradient(colors: [Club.Colors.volt.opacity(0.20), Color.clear], center: .center, startRadius: 20, endRadius: 160))
                        .frame(width: 300, height: 300)
                }

                ZStack {
                    Image(draft.chosenPot)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 230, height: 230)
                        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)

                    if pitTapCount < 2 {
                        Image("pit_in_soil")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 230, height: 230)
                            .rotationEffect(.degrees(pitWobble))
                    } else if pitTapCount == 2 {
                        Image("pit_crack")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 230, height: 230)
                            .rotationEffect(.degrees(pitWobble))
                    } else {
                        Image("pip_wave")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .offset(y: -50)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .frame(height: 290)
            .contentShape(Rectangle())
            .onTapGesture { handlePitTap() }
            // Canvas bigger than the stage so the burst isn't cut off at its edges.
            .overlay(ConfettiBurst(trigger: pitTapCount >= 3 ? 1 : 0, big: true, origin: UnitPoint(x: 0.5, y: 0.5))
                .frame(width: 700, height: 1000))
            .revealIn(1)

            if pitTapCount < 3 {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { idx in
                            Circle()
                                .fill(idx < pitTapCount ? Club.Colors.volt : Club.Colors.surfaceRaised)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Club.Colors.volt, lineWidth: idx < pitTapCount ? 0 : 1))
                        }
                    }
                    Text(3 - pitTapCount == 1 ? "One more tap!" : "Tap the pit (\(max(0, 3 - pitTapCount)) taps left)")
                        .font(Club.Fonts.caption)
                        .foregroundStyle(Club.Colors.textSecondary)
                }
                .padding(.vertical, 6)
                .revealIn(2)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Club.Colors.antiqueBrass)
                    Text("A baby avocado popped out to cheer you on!")
                        .font(Club.Fonts.headline)
                        .foregroundStyle(Club.Colors.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Club.Colors.volt.opacity(0.12), in: Capsule())
                .revealIn(2)
            }
        }
    }

    private func handlePitTap() {
        guard pitTapCount < 3 else {
            Haptics.tap()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) {
                pitWobble = (pitWobble == 0) ? 7 : -pitWobble
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.25)) { pitWobble = 0 }
            }
            return
        }

        pitTapCount += 1

        if pitTapCount == 1 {
            Haptics.tap()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.4)) { pitWobble = 12 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.22)) { pitWobble = 0 }
            }
        } else if pitTapCount == 2 {
            Haptics.warning()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.4)) { pitWobble = -16 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.22)) { pitWobble = 0 }
            }
        } else if pitTapCount >= 3 {
            Haptics.success()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { pitWobble = 0 }
        }
    }

    // MARK: - Slide 2: Name Companion

    private var namePipStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Companion Bond")
                    .font(Club.Fonts.clubTag(11)).tracking(1.8)
                    .foregroundStyle(Club.Colors.antiqueBrass)
                    .revealIn(0)
                HighlightHeadline(text: "Name your avocado pal", highlight: "avocado pal", size: 32)
                    .revealIn(0)
                Text("Give your new nutrition buddy a name! They'll cheer your healthy meals, drink water with you, and watch out for allergens.")
                    .font(Club.Fonts.body)
                    .foregroundStyle(Club.Colors.textSecondary)
                    .revealIn(1)
            }

            HStack {
                Spacer()
                Image("pip_happy")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 170)
                    .shadow(color: Color.black.opacity(0.06), radius: 10, y: 6)
                Spacer()
            }
            .revealIn(1)

            VStack(alignment: .leading, spacing: 10) {
                Text("Avocado Pal's Name")
                    .font(Club.Fonts.caption)
                    .foregroundStyle(Club.Colors.textSecondary)

                TextField("e.g. Pip, Guac, Sprout", text: $draft.companionName)
                    .onChange(of: draft.companionName) { name in
                        // Long names break headings like "Calibrating ___'s plan".
                        if name.count > Self.maxNameLength { draft.companionName = String(name.prefix(Self.maxNameLength)) }
                    }
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Club.Colors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Club.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Club.Colors.parchmentBorder, lineWidth: 1))

                HStack(spacing: 8) {
                    Text("Suggestions:")
                        .font(Club.Fonts.caption)
                        .foregroundStyle(Club.Colors.textTertiary)
                    ForEach(["Pip", "Guac", "Sprout", "Avie", "Nori"], id: \.self) { sug in
                        Button {
                            Haptics.tap()
                            draft.companionName = sug
                        } label: {
                            Text(sug)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(draft.companionName == sug ? Club.Colors.volt.opacity(0.15) : Club.Colors.surfaceRaised, in: Capsule())
                                .foregroundStyle(draft.companionName == sug ? Club.Colors.volt : Club.Colors.textSecondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .card()
            .revealIn(2)
        }
    }

    // MARK: - Slide 3: Gender / Biological Sex

    private var genderStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Metabolic Profile")
                    .font(Club.Fonts.clubTag(11)).tracking(1.8)
                    .foregroundStyle(Club.Colors.antiqueBrass)
                    .revealIn(0)
                HighlightHeadline(text: "Which profile is yours?", highlight: "yours?", size: 32)
                    .revealIn(0)
                Text("\(draft.companionName) uses this to work out how much energy your body uses each day.")
                    .font(Club.Fonts.body)
                    .foregroundStyle(Club.Colors.textSecondary)
                    .revealIn(1)
            }

            HStack(spacing: 14) {
                Image("pip_point")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 85, height: 85)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(draft.companionName) asks:")
                        .font(Club.Fonts.caption)
                        .foregroundStyle(Club.Colors.volt)
                    Text("Bodies burn energy a little differently. This only changes the math for your calories.")
                        .font(Club.Fonts.body)
                        .foregroundStyle(Club.Colors.textPrimary)
                }
                .padding(12)
                .background(Club.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Club.Colors.parchmentBorder, lineWidth: 1))
            }
            .revealIn(1)

            HStack(spacing: 14) {
                genderButton("Male", symbol: "figure.walk")
                genderButton("Female", symbol: "figure.walk.motion")
            }
            .revealIn(2)

            Text("You can change this any time in Profile.")
                .font(Club.Fonts.caption)
                .foregroundStyle(Club.Colors.textTertiary)
                .revealIn(3)
        }
    }

    private func genderButton(_ title: String, symbol: String) -> some View {
        let isSelected = draft.gender == title
        return Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { draft.gender = title }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(isSelected ? Club.Colors.volt : Club.Colors.textSecondary)
                    .frame(height: 44)

                Text(title)
                    .font(Club.Fonts.headline)
                    .foregroundStyle(Club.Colors.textPrimary)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Club.Colors.volt : Club.Colors.textTertiary)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Club.Colors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Club.Colors.volt : Club.Colors.parchmentBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Slide 4: Allergens & Triggers

    private var triggersStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sensitive Belly Defense")
                    .font(Club.Fonts.clubTag(11)).tracking(1.8)
                    .foregroundStyle(Club.Colors.antiqueBrass)
                    .revealIn(0)
                HighlightHeadline(text: "What upsets our tummy?", highlight: "upsets our tummy?", size: 32)
                    .revealIn(0)
                Text("Pick everything you avoid. \(draft.companionName) will screen ingredients and keep our stomach safe.")
                    .font(Club.Fonts.body)
                    .foregroundStyle(Club.Colors.textSecondary)
                    .revealIn(1)
            }

            HStack(spacing: 14) {
                Image("pip_bloated")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 85, height: 85)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(draft.companionName) says:")
                        .font(Club.Fonts.caption)
                        .foregroundStyle(Club.Colors.danger)
                    Text("Oof, bad ingredients give me a bloated tummy too! Tap all foods to avoid:")
                        .font(Club.Fonts.body)
                        .foregroundStyle(Club.Colors.textPrimary)
                }
                .padding(12)
                .background(Club.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Club.Colors.danger.opacity(0.2), lineWidth: 1))
            }
            .revealIn(1)

            ColorChips(items: allTriggerOptions,
                       selected: $draft.allergenNames,
                       onAddCustom: { customTriggerText = ""; showCustomTrigger = true })
                .revealIn(2)
                // "Nothing" and a real trigger can't both be true.
                .onChange(of: draft.allergenNames) { new in
                    if new.contains(Self.noTriggers), new.count > 1 {
                        let addedNothing = !previousTriggers.contains(Self.noTriggers)
                        draft.allergenNames = addedNothing ? [Self.noTriggers] : new.subtracting([Self.noTriggers])
                    }
                    previousTriggers = draft.allergenNames
                }
        }
    }

    // MARK: - Slide 5: Severity

    private var severityStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Reaction Threshold")
                    .font(Club.Fonts.clubTag(11)).tracking(1.8)
                    .foregroundStyle(Club.Colors.antiqueBrass)
                    .revealIn(0)
                HighlightHeadline(text: "How severe is each reaction?", highlight: "each reaction?", size: 32)
                    .revealIn(0)
                Text("\(draft.companionName) customizes cross-contact warnings based on your tolerance.")
                    .font(Club.Fonts.body)
                    .foregroundStyle(Club.Colors.textSecondary)
                    .revealIn(1)
            }

            HStack(spacing: 14) {
                Image("pip_think")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 85, height: 85)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(draft.companionName) notes:")
                        .font(Club.Fonts.caption)
                        .foregroundStyle(Club.Colors.volt)
                    Text("We calibrate between strict cross-contamination alerts or general awareness.")
                        .font(Club.Fonts.body)
                        .foregroundStyle(Club.Colors.textPrimary)
                }
                .padding(12)
                .background(Club.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Club.Colors.parchmentBorder, lineWidth: 1))
            }
            .revealIn(1)

            let filteredTriggers = draft.allergenNames.filter { $0 != Self.noTriggers }
            if filteredTriggers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Club.Colors.safe)
                    Text("No Triggers Selected")
                        .font(Club.Fonts.headline)
                        .foregroundStyle(Club.Colors.textPrimary)
                    Text("\(draft.companionName) will focus purely on your \(draft.gender.lowercased()) macro targets and workout fueling.")
                        .font(Club.Fonts.caption)
                        .foregroundStyle(Club.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .card()
                .revealIn(2)
            } else {
                ForEach(Array(Array(filteredTriggers).sorted().enumerated()), id: \.element) { idx, name in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(name)
                            .font(Club.Fonts.headline)
                            .foregroundStyle(Club.Colors.textPrimary)

                        HStack(spacing: 6) {
                            ForEach(Sensitivity.allCases) { s in
                                Button {
                                    Haptics.tap()
                                    draft.severityByName[name] = s.rawValue
                                } label: {
                                    Text(s.short)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 38)
                                        .background(selected(name) == s ? s.color.opacity(0.9)
                                                                        : Club.Colors.surface,
                                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .foregroundStyle(selected(name) == s ? Club.Colors.onVolt
                                                                             : Club.Colors.textSecondary)
                                }
                            }
                        }
                    }
                    .card()
                    .revealIn(idx + 2)
                }
            }
        }
    }

    private func selected(_ name: String) -> Sensitivity {
        Sensitivity(rawValue: draft.severityByName[name] ?? "moderate") ?? .moderate
    }

    // MARK: - Slide 6: Goal (Gender-Specific)

    private var goalStep: some View {
        let options: [(key: String, title: String, sub: String, symbol: String)] = [
            ("lose",   "Lose weight",           "A gentle deficit that still leaves you full of energy.", "arrow.down.right"),
            ("build",  "Build muscle",          "More protein and energy to hit personal records.",       "dumbbell.fill"),
            ("gut",    "Calm my gut",           "Fewer bloated, uncomfortable, painful days.",            "leaf.fill"),
            ("steady", "Keep weight steady",    "Eat nutritious meals and maintain healthy energy.",      "scalemass.fill")
        ]
        let picks = Set(draft.goalPicks ?? [])
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Companion Goals")
                    .font(Club.Fonts.clubTag(11)).tracking(1.8)
                    .foregroundStyle(Club.Colors.antiqueBrass)
                    .revealIn(0)
                HighlightHeadline(text: "What are our goals together?", highlight: "our goals", size: 32)
                    .revealIn(0)
                Text("Pick as many as you like. Every goal you hit earns seeds to spend on \(draft.companionName)!")
                    .font(Club.Fonts.body)
                    .foregroundStyle(Club.Colors.textSecondary)
                    .revealIn(1)
            }

            HStack(spacing: 14) {
                Image("pip_cheer")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 85, height: 85)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(draft.companionName) cheers:")
                        .font(Club.Fonts.caption)
                        .foregroundStyle(Club.Colors.volt)
                    Text("Whatever you choose, we'll hit every target step by step!")
                        .font(Club.Fonts.body)
                        .foregroundStyle(Club.Colors.textPrimary)
                }
                .padding(12)
                .background(Club.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Club.Colors.parchmentBorder, lineWidth: 1))
            }
            .revealIn(1)

            ForEach(Array(options.enumerated()), id: \.element.key) { i, o in
                Button { toggleGoal(o.key) } label: {
                    GoalOptionCard(symbol: o.symbol, title: o.title, subtitle: o.sub,
                                   isSelected: picks.contains(o.key),
                                   isDimmed: !picks.isEmpty && !picks.contains(o.key))
                }
                .buttonStyle(.plain)
                .revealIn(i + 2)
            }

            if picks.contains("lose") && picks.contains("build") {
                Label("Both together: a smaller deficit with extra protein, so you lose fat while you build.",
                      systemImage: "arrow.triangle.2.circlepath")
                    .font(Club.Fonts.caption)
                    .foregroundStyle(Club.Colors.textSecondary)
                    .padding(.top, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// Lose and build combine; "steady" can't sit with either; gut is
    /// independent. The calorie direction is derived, never asked for.
    private func toggleGoal(_ key: String) {
        Haptics.tap()
        var p = Set(draft.goalPicks ?? [])
        if p.contains(key) {
            p.remove(key)
        } else {
            p.insert(key)
            if key == "steady" { p.subtract(["lose", "build"]) }
            if key == "lose" || key == "build" { p.remove("steady") }
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            draft.goalPicks = p.sorted()
            let lose = p.contains("lose"), build = p.contains("build")
            draft.goal = lose && build ? "Recomp" : lose ? "Cut" : build ? "Build muscle" : "Maintain"
            draft.gutFocus = p.contains("gut")
        }
    }

    // MARK: - Slide 7: Wearable & Activity Tracking

    private var wearableStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Hardware Sync")
                    .font(Club.Fonts.clubTag(11)).tracking(1.8)
                    .foregroundStyle(Club.Colors.antiqueBrass)
                    .revealIn(0)
                HighlightHeadline(text: "Which device tracks your workouts?", highlight: "tracks your workouts", size: 30)
                    .revealIn(0)
                Text("\(draft.companionName) syncs with Apple Health to automatically adjust your calories when you train.")
                    .font(Club.Fonts.body)
                    .foregroundStyle(Club.Colors.textSecondary)
                    .revealIn(1)
            }

            HStack(spacing: 14) {
                Image("pip_proud")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 85, height: 85)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(draft.companionName) stretches:")
                        .font(Club.Fonts.caption)
                        .foregroundStyle(Club.Colors.volt)
                    Text("Moving every day gives us both energy points! Connect your device:")
                        .font(Club.Fonts.body)
                        .foregroundStyle(Club.Colors.textPrimary)
                }
                .padding(12)
                .background(Club.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Club.Colors.parchmentBorder, lineWidth: 1))
            }
            .revealIn(1)

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
                            .foregroundStyle(draft.wearable == w.0 ? Club.Colors.volt : Club.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Club.Colors.surfaceRaised, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.0)
                                .font(Club.Fonts.headline)
                                .foregroundStyle(Club.Colors.textPrimary)
                            Text(w.2)
                                .font(Club.Fonts.caption)
                                .foregroundStyle(Club.Colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: draft.wearable == w.0 ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(draft.wearable == w.0 ? Club.Colors.volt : Club.Colors.textTertiary)
                    }
                    .card()
                }
                .buttonStyle(.plain)
                .revealIn(idx + 2)
            }
        }
    }

    // MARK: - Slide 8: Personal Stats (Gender-Specific BMR)

    private var statsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Body Calibration")
                    .font(Club.Fonts.clubTag(11)).tracking(1.8)
                    .foregroundStyle(Club.Colors.antiqueBrass)
                    .revealIn(0)
                HighlightHeadline(text: "Your daily measurements.", highlight: "daily measurements.", size: 30)
                    .revealIn(0)
                Text("\(draft.companionName) needs your height, weight and how often you train to set your daily targets.")
                    .font(Club.Fonts.body)
                    .foregroundStyle(Club.Colors.textSecondary)
                    .revealIn(1)
            }

            HStack(spacing: 14) {
                Image("pip_happy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(draft.companionName) notes:")
                        .font(Club.Fonts.caption)
                        .foregroundStyle(Club.Colors.volt)
                    Text("These set a calorie target that works for your body. You can change them any time.")
                        .font(Club.Fonts.body)
                        .foregroundStyle(Club.Colors.textPrimary)
                }
                .padding(12)
                .background(Club.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Club.Colors.parchmentBorder, lineWidth: 1))
            }
            .revealIn(1)

            stepper("Training days / week", value: $draft.trainingDays, range: 0...7, suffix: " days")
            stepper("Weight", value: $draft.weightLb, range: 70...500, suffix: " lb", by: 5)
            stepper("Height (ft)", value: $draft.heightFeet, range: 3...7, suffix: "'")
            stepper("Height (in)", value: $draft.heightInches, range: 0...11, suffix: "\"")
            stepper("Age", value: $draft.age, range: 13...100, suffix: " yrs")
        }
    }

    private func stepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>,
                         suffix: String, by: Int = 1) -> some View {
        HStack {
            Text(label).font(Club.Fonts.body).foregroundStyle(Club.Colors.textSecondary)
            Spacer()
            Button {
                if value.wrappedValue - by >= range.lowerBound {
                    Haptics.tap(); value.wrappedValue -= by
                }
            } label: {
                Image(systemName: "minus").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Club.Colors.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Club.Colors.surfaceRaised, in: Circle())
            }
            Text("\(value.wrappedValue)\(suffix)")
                .font(Club.Fonts.headline).foregroundStyle(Club.Colors.textPrimary)
                .frame(minWidth: 64)
            Button {
                if value.wrappedValue + by <= range.upperBound {
                    Haptics.tap(); value.wrappedValue += by
                }
            } label: {
                Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Club.Colors.onVolt)
                    .frame(width: 34, height: 34)
                    .background(Club.Colors.volt, in: Circle())
            }
        }
        .card()
    }

    // MARK: - Slide 9: Dynamic Plan Generation & Gender Blueprint Reveal

    private var calculationAndPayoffStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !calculationComplete {
                generatingCard
            } else {
                planRevealCard
            }
        }
        .overlay(alignment: .top) {
            ConfettiBurst(trigger: calculationComplete ? 1 : 0, origin: UnitPoint(x: 0.5, y: 0.3))
                .frame(width: 700, height: 1000)
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
                    .stroke(Club.Colors.surfaceRaised, lineWidth: 8)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: calculationProgress)
                    .stroke(Club.Colors.volt, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: calculationProgress)

                VStack(spacing: 2) {
                    Image("pip_eat")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 75, height: 75)
                    Text("\(Int(calculationProgress * 100))%")
                        .font(Club.Fonts.stat(18))
                        .foregroundStyle(Club.Colors.textPrimary)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                Text(phaseTitle)
                    .font(Club.Fonts.headline)
                    .foregroundStyle(Club.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("\(draft.companionName) is baking our custom fuel plan with \(draft.allergenNames.count) safe triggers and \(draft.wearable) sync.")
                    .font(Club.Fonts.caption)
                    .foregroundStyle(Club.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                calcCheckItem(title: "Allergen matrix screening", done: calculationProgress >= 0.25)
                calcCheckItem(title: "\(draft.companionName) energy baseline calibration", done: calculationProgress >= 0.50)
                calcCheckItem(title: "Wearable energy balance integration", done: calculationProgress >= 0.75)
                calcCheckItem(title: "Custom macro blueprint optimization", done: calculationProgress >= 0.98)
            }
            .padding(16)
            .background(Club.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func calcCheckItem(title: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(done ? Club.Colors.volt : Club.Colors.textTertiary)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(done ? Club.Colors.textPrimary : Club.Colors.textTertiary)
            Spacer()
        }
    }

    private var phaseTitle: String {
        switch calculationPhase {
        case 0: return "Analyzing Allergy Triggers..."
        case 1: return "Calibrating \(draft.companionName)'s Energy Baseline..."
        case 2: return "Optimizing Protein & Nutrient Ratios..."
        default: return "Finalizing Your \(draft.companionName) Blueprint..."
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
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await AdAttribution.requestTrackingIfNeeded()
        }
    }

    private var planRevealCard: some View {
        let t = draft.targets
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image("pip_proud")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 85, height: 85)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(draft.companionName)'s Plan is Ready!")
                        .font(Club.Fonts.caption)
                        .foregroundStyle(Club.Colors.volt)
                    HighlightHeadline(text: "Got it. Here's our plan.", highlight: "our plan.", size: 24)
                }
            }

            HStack(spacing: 8) {
                target(t.calories.formatted(.number.grouping(.automatic)), "calories", Club.Colors.volt)
                target("\(t.protein)g", "protein", Club.Colors.protein)
                target("\(t.carbs)g", "carbs", Club.Colors.carbs)
                target("\(t.fat)g", "fat", Club.Colors.fat)
            }

            GotItCard(name: "\(draft.companionName)'s Profile", chips: gotItChips)

            Text("SafeFuel learns as you log, too. Create a free account to save this and start.")
                .font(Club.Fonts.caption)
                .foregroundStyle(Club.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Everything they told us, as chips — the proof that the app listened.
    private var gotItChips: [(String, HeroTint)] {
        var out: [(String, HeroTint)] = [(draft.gender, .sky)]
        let triggers = draft.allergenNames.filter { $0 != Self.noTriggers }.sorted()
        for (i, t) in triggers.enumerated() { out.append((t, HeroTint.at(i + 1))) }
        let goalLabel: String = {
            switch draft.goal {
            case "Cut": return "Lose weight"
            case "Recomp": return "Lose fat & build muscle"
            case "Build muscle": return "Build muscle"
            default: return "Steady weight"
            }
        }()
        out.append((goalLabel, .mint))
        if draft.gutFocus == true { out.append(("Calm my gut", .sand)) }
        out.append(("\(draft.trainingDays)× a week", .amber))
        if !draft.wearable.isEmpty { out.append((draft.wearable, .lilac)) }
        return out
    }

    private func target(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 3) {
            Text(v).font(Club.Fonts.stat(19)).foregroundStyle(c)
            Text(l).font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Club.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Club.Colors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Slide 10: Account Creation (Second-to-Last Slide)

    private var accountCreationStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image("pip_hug")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 85, height: 85)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(draft.companionName) is ready!")
                        .font(Club.Fonts.caption)
                        .foregroundStyle(Club.Colors.volt)
                    HighlightHeadline(text: "Save our journey.", highlight: "our journey.", size: 26)
                }
            }

            Text("An account keeps your targets, triggers and \(draft.companionName)'s streak safe if you change phones.")
                .font(Club.Fonts.body)
                .foregroundStyle(Club.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let authErrorMessage {
                Text(authErrorMessage)
                    .font(Club.Fonts.caption)
                    .foregroundStyle(Club.Colors.danger)
                    .padding(10)
                    .background(Club.Colors.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
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
                            .font(Club.Fonts.headline)
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
                    Rectangle().fill(Club.Colors.surfaceRaised).frame(height: 1)
                    Text("or use email").font(Club.Fonts.caption).foregroundStyle(Club.Colors.textTertiary)
                    Rectangle().fill(Club.Colors.surfaceRaised).frame(height: 1)
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
                            ProgressView().tint(Club.Colors.onVolt)
                        } else {
                            Text(isSigningUp ? "Create Account & Continue" : "Sign In & Continue")
                                .font(Club.Fonts.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Club.Colors.volt)
                    .foregroundStyle(Club.Colors.onVolt)
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
                        .font(Club.Fonts.caption)
                        .foregroundStyle(Club.Colors.textSecondary)
                }

                Button {
                    Task { await skipAccount() }
                } label: {
                    VStack(spacing: 3) {
                        Text("Skip for now")
                            .font(Club.Fonts.headline)
                            .foregroundStyle(Club.Colors.textPrimary)
                        Text("You can save your plan to an account any time in Profile.")
                            .font(Club.Fonts.caption)
                            .foregroundStyle(Club.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .disabled(authBusy)
                .padding(.top, 6)
            }
        }
    }

    /// "Skip" signs in anonymously rather than faking a guest mode: the person
    /// gets a real, private account, so everything they log saves exactly as
    /// it would for anyone else, and Profile → Save your account attaches an
    /// email later without losing a thing.
    @MainActor
    private func skipAccount() async {
        authBusy = true
        defer { authBusy = false }
        authErrorMessage = nil
        do {
            if session.session == nil {
                _ = try await Backend.client.auth.signInAnonymously()
            }
            Haptics.tap()
            isMovingForward = true
            finish()
        } catch {
            authErrorMessage = "Couldn't continue without an account right now. Check your connection, or create one above."
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
            finish()
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
            finish()
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
                finish()
            } else {
                _ = try await Backend.client.auth.signIn(email: mail, password: pass)
                Haptics.success()
                isMovingForward = true
                finish()
            }
        } catch {
            authErrorMessage = AuthView.friendlyAuthMessage(error)
        }
    }
}
