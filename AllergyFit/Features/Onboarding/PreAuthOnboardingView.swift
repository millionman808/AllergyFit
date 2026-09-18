import SwiftUI
import AuthenticationServices
import Supabase
import GoogleSignIn

/// The "Old Money Athletic Club Kitchen" Onboarding Experience.
/// Features a persistent Carrara marble prep counter, tactile physical kitchen stations,
/// flat-lay tailored apparel (no mannequins), apothecary ingredient jars,
/// mechanical brass balance scales, and unfolding cardstock menu blueprints.
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

    /// Standard pantry provision jars plus custom entries
    private var allTriggerOptions: [String] {
        ["No Allergens (Track Fuel)", "Peanuts", "Tree Nuts", "Milk / Dairy", "Eggs", "Gluten / Wheat", "Soy", "Fish", "Shellfish", "Sesame"] + draft.customAllergens
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            if step == 9 {
                // Final Slide: The Honorary Club Membership Card (Paywall)
                PaywallView(source: "onboarding", onDismiss: {
                    finish()
                })
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    topBar
                        .padding(.top, 8)
                        .padding(.horizontal, 20)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            content
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                        .id(step)
                        .transition(reduceMotion ? .opacity : .directionalSlide(forward: isMovingForward))
                    }
                    .animation(reduceMotion ? .easeOut(duration: 0.15)
                                            : .spring(response: 0.44, dampingFraction: 0.86), value: step)

                    if step != 8 {
                        footer
                    }

                    // Persistent Marble & Brass Kitchen Prep Counter
                    PrepCounterSurface()
                }
            }
        }
        .alert("Add a Custom Provision", isPresented: $showCustomTrigger) {
            TextField("e.g. Mango, Sulphites, Nightshades", text: $customTriggerText)
                .textInputAutocapitalization(.never)
            Button("Cancel", role: .cancel) {}
            Button("Add Provision") { addCustomTrigger() }
        } message: {
            Text("Specify any ingredient that must be quarantined from your meals.")
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Colors.racingGreen)
                    .frame(width: 34, height: 34)
                    .background(Theme.Colors.surface, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.Colors.parchmentBorder, lineWidth: 1))
            }
            .opacity(step == 0 ? 0 : 1)
            .disabled(step == 0)

            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Theme.Colors.racingGreen : Theme.Colors.surfaceRaised)
                        .frame(height: i == step ? 4 : 2.5)
                }
            }
            .animation(.spring(response: 0.35), value: step)

            if !session.isSignedIn && step == 0 {
                Button {
                    if let onSignIn { onSignIn() } else { finish() }
                } label: {
                    Text("SIGN IN")
                        .font(Theme.Fonts.clubTag(10))
                        .tracking(1.5)
                        .foregroundStyle(Theme.Colors.racingGreen)
                }
            } else {
                Color.clear.frame(width: 50, height: 34)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button { advance() } label: {
                HStack(spacing: 8) {
                    Text(step == 7 ? "Review & Seal Blueprint" : "Proceed")
                        .font(Theme.Fonts.headline)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canAdvance ? Theme.Colors.racingGreen : Theme.Colors.surfaceRaised,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.Colors.antiqueBrass.opacity(canAdvance ? 0.35 : 0), lineWidth: 1)
                )
            }
            .disabled(!canAdvance)
            .pressable()
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 6)
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
        case 0: porticoWelcomeStep
        case 1: wardrobeLockerStep
        case 2: pantryLarderStep
        case 3: quarantineTrayStep
        case 4: trainingAnnexStep
        case 5: timepieceValetStep
        case 6: scalesAndLedgerStep
        case 7: chefsTableStep
        case 8: memberRegistryStep
        default: EmptyView()
        }
    }

    private func header(_ title: String, _ sub: String, tag: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let tag {
                Text(tag.uppercased())
                    .font(Theme.Fonts.clubTag(10))
                    .tracking(2.5)
                    .foregroundStyle(Theme.Colors.antiqueBrass)
            }
            Text(title)
                .font(Theme.Fonts.display(28))
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(sub)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Slide 0: The Club Portico (Welcome)

    private var porticoWelcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Club Crest Insignia Plaque
            ZStack {
                Circle()
                    .fill(Theme.Colors.racingGreen)
                    .frame(width: 74, height: 74)
                    .overlay(Circle().strokeBorder(Theme.Colors.antiqueBrass, lineWidth: 2))
                    .shadow(color: Theme.Colors.racingGreen.opacity(0.35), radius: 14, y: 5)

                Image(systemName: "laurel.leading")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Theme.Colors.antiqueBrass)
                    .offset(x: -12)

                Image(systemName: "shield.checkered")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.white)

                Image(systemName: "laurel.trailing")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Theme.Colors.antiqueBrass)
                    .offset(x: 12)
            }
            .padding(.top, 10)
            .revealIn(0)

            header("SafeFuel Pavilion",
                   "The private nutrition and athletic fueling club for athletes with food sensitivities.",
                   tag: "Est. 2026 • Member Admission")
                .revealIn(1)

            VStack(alignment: .leading, spacing: 12) {
                bulletPill("shield.checkered", "Zero-Trace Allergen Quarantine", "Every ingredient screened against your personal sensitivity matrix.")
                    .revealIn(2)
                bulletPill("bolt.heart.fill", "Live Chronometer Calibration", "Dynamic caloric replenishment synced from your smartwatch.")
                    .revealIn(3)
                bulletPill("gauge.with.needle.fill", "Daily Nutrition Recovery Score", "Precision 0–100 fuel quality ledger and micronutrient balance.")
                    .revealIn(4)
                bulletPill("fork.knife", "Bespoke Chef Meal Blueprints", "Weekly chef-crafted culinary plans strictly devoid of your triggers.")
                    .revealIn(5)
            }
            .padding(.top, 4)

            if !session.isSignedIn {
                Button {
                    if let onSignIn { onSignIn() } else { finish() }
                } label: {
                    HStack(spacing: 6) {
                        Text("Already inscribed in the club registry?")
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text("Sign in")
                            .foregroundStyle(Theme.Colors.racingGreen)
                            .font(Theme.Fonts.headline)
                    }
                    .font(Theme.Fonts.caption)
                    .padding(.top, 6)
                }
                .revealIn(6)
            }
        }
    }

    private func bulletPill(_ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.racingGreen.opacity(0.08))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.racingGreen)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Slide 1: The Wardrobe (Tailored Apparel / Gender Intake)

    private var wardrobeLockerStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("The Member's Wardrobe",
                   "Select your profile. Basal metabolic rate, hormone regulation, and protein synthesis thresholds differ by biological sex.",
                   tag: "Locker Suite • Step I")
                .revealIn(0)

            HStack(spacing: 14) {
                // Gentleman's Kit Card
                outfitCard(
                    title: "Gentleman",
                    subtitle: "MSJ +5 kcal baseline",
                    imageName: "GentlemansKit",
                    fallbackPath: "/Users/elischafer/Developer/AllergyFit/AllergyFit/Resources/Assets.xcassets/GentlemansKit.imageset/gentlemans_kit.jpg",
                    tag: "LOCKER 01",
                    gender: "Male",
                    isSelected: draft.gender == "Male",
                    bullets: ["2.0g/kg protein synthesis", "Power & strength density", "Zinc & magnesium recovery"]
                )
                .revealIn(1)

                // Lady's Kit Card
                outfitCard(
                    title: "Lady",
                    subtitle: "MSJ -161 kcal baseline",
                    imageName: "LadysKit",
                    fallbackPath: "/Users/elischafer/Developer/AllergyFit/AllergyFit/Resources/Assets.xcassets/LadysKit.imageset/ladys_kit.jpg",
                    tag: "LOCKER 02",
                    gender: "Female",
                    isSelected: draft.gender == "Female",
                    bullets: ["1.8g/kg lean muscle tone", "Cycle-aware hormone fuel", "Iron & calcium shield"]
                )
                .revealIn(2)
            }
        }
    }

    private func outfitCard(title: String, subtitle: String, imageName: String, fallbackPath: String,
                            tag: String, gender: String, isSelected: Bool, bullets: [String]) -> some View {
        Button {
            Haptics.tap()
            draft.gender = gender
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Top Tag & Lock In
                HStack {
                    Text(tag)
                        .font(Theme.Fonts.clubTag(9))
                        .tracking(1.5)
                        .foregroundStyle(isSelected ? Theme.Colors.antiqueBrass : Theme.Colors.textTertiary)

                    Spacer()

                    if isSelected {
                        WaxSealStamp(text: "SF", size: 24)
                    } else {
                        Circle()
                            .strokeBorder(Theme.Colors.parchmentBorder, lineWidth: 1)
                            .frame(width: 18, height: 18)
                    }
                }

                // Flat-lay Outfit Photograph
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.Colors.surfaceRaised)
                        .frame(height: 145)

                    if let uiImage = UIImage(named: imageName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 145)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else if let bundlePath = Bundle.main.path(forResource: imageName, ofType: "jpg"),
                              let uiImage = UIImage(contentsOfFile: bundlePath) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 145)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else if let uiImage = UIImage(contentsOfFile: fallbackPath) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 145)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Image(systemName: "tshirt.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.Colors.racingGreen)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? Theme.Colors.antiqueBrass : Color.clear, lineWidth: 1.5)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Fonts.display(18))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(bullets, id: \.self) { b in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(isSelected ? Theme.Colors.racingGreen : Theme.Colors.textTertiary)
                            Text(b)
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(12)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Theme.Colors.racingGreen : Theme.Colors.parchmentBorder,
                                  lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.02), radius: 8, y: 4)
            .opacity(isSelected ? 1.0 : 0.75)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Slide 2: The Club Pantry (Allergen Jars)

    private var pantryLarderStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("The Member's Pantry",
                   "Select every provision to be quarantined from your kitchen. Stamped items will never appear in your meals.",
                   tag: "Larder & Quarantine • Step II")
                .revealIn(0)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(allTriggerOptions, id: \.self) { item in
                    apothecaryJarCard(item)
                }
            }
            .revealIn(1)

            Button {
                customTriggerText = ""
                showCustomTrigger = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.Colors.antiqueBrass)
                    Text("Add Custom Quarantined Provision")
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.racingGreen)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Colors.parchmentBorder, lineWidth: 1))
            }
            .revealIn(2)
        }
    }

    private func apothecaryJarCard(_ name: String) -> some View {
        let isExcluded = draft.allergenNames.contains(name)
        return Button {
            Haptics.tap()
            if isExcluded {
                draft.allergenNames.remove(name)
            } else {
                if name.contains("No Allergens") {
                    draft.allergenNames.removeAll()
                } else {
                    draft.allergenNames.remove("No Allergens (Track Fuel)")
                }
                draft.allergenNames.insert(name)
            }
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    // Vintage Ceramic Jar Icon
                    Image(systemName: isExcluded ? "xmark.shield.fill" : "cylinder.split.1x2.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(isExcluded ? Theme.Colors.waxCrimson : Theme.Colors.antiqueBrass)
                }

                Text(name)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(isExcluded ? Theme.Colors.waxCrimson : Theme.Colors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if isExcluded {
                    Text("EXCLUDE")
                        .font(Theme.Fonts.clubTag(8))
                        .tracking(1.0)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.waxCrimson, in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
            .background(isExcluded ? Theme.Colors.waxCrimson.opacity(0.06) : Theme.Colors.surface,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isExcluded ? Theme.Colors.waxCrimson.opacity(0.6) : Theme.Colors.parchmentBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Slide 3: The Quarantine Tray (Severity Inspection)

    private var quarantineTrayStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("Quarantine Protocol",
                   "Calibrate cross-contamination threshold inspection for each flagged ingredient.",
                   tag: "Inspection Tray • Step III")
                .revealIn(0)

            let filteredTriggers = draft.allergenNames.filter { !$0.contains("No Allergens") }
            if filteredTriggers.isEmpty {
                VStack(spacing: 12) {
                    WaxSealStamp(text: "CLEAR", size: 42, color: Theme.Colors.racingGreen)
                    Text("Pantry Cleared")
                        .font(Theme.Fonts.display(20))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("No quarantine restrictions active. SafeFuel will focus purely on your \(draft.gender.lowercased()) macro targets.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .card()
            } else {
                ForEach(Array(Array(filteredTriggers).sorted().enumerated()), id: \.element) { idx, name in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(name)
                                .font(.system(size: 15, weight: .semibold, design: .serif))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Text("PROTOCOL")
                                .font(Theme.Fonts.clubTag(9))
                                .tracking(1.5)
                                .foregroundStyle(Theme.Colors.antiqueBrass)
                        }

                        HStack(spacing: 6) {
                            ForEach(Sensitivity.allCases) { s in
                                Button {
                                    Haptics.tap()
                                    draft.severityByName[name] = s.rawValue
                                } label: {
                                    Text(s.short)
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 36)
                                        .background(selected(name) == s ? Theme.Colors.racingGreen
                                                                        : Theme.Colors.surface,
                                                    in: RoundedRectangle(cornerRadius: 10))
                                        .foregroundStyle(selected(name) == s ? Color.white
                                                                             : Theme.Colors.textSecondary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(selected(name) == s ? Theme.Colors.antiqueBrass : Theme.Colors.parchmentBorder, lineWidth: 1)
                                        )
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

    // MARK: - Slide 4: The Training Annex (Athletic Goal)

    private var trainingAnnexStep: some View {
        let isFemale = draft.gender == "Female"
        let goals: [(String, String, String, String)] = isFemale ? [
            ("Build Lean Muscle & Tone", "Sculpting with 1.8g/kg protein threshold", "figure.strengthtraining.traditional", "HYPERTROPHY"),
            ("Maintain & Vitality", "Steady endocrine energy & cycle-aware balance", "figure.run", "EQUILIBRIUM"),
            ("Fat Loss & Definition", "Hormone-sparing gradual caloric deficit", "flame.fill", "DEFICIT")
        ] : [
            ("Build Muscle & Strength", "Hypertrophy focus with 2.0g/kg protein surplus", "figure.strengthtraining.traditional", "SURPLUS"),
            ("Maintain & Performance", "High-output athletic power & conditioning", "figure.run", "EQUILIBRIUM"),
            ("Cut & Definition", "Precision deficit sparing maximum muscle tissue", "flame.fill", "DEFICIT")
        ]

        return VStack(alignment: .leading, spacing: 16) {
            header("The Training Annex",
                   "Select your primary objective to calibrate your daily calories and macronutrient ledger.",
                   tag: "Athletic Program • Step IV")
                .revealIn(0)

            ForEach(Array(goals.enumerated()), id: \.element.0) { idx, item in
                let targetKey = item.0.contains("Build") ? "Build muscle" : item.0.contains("Cut") || item.0.contains("Fat") ? "Cut" : "Maintain"
                let isSelected = draft.goal == targetKey

                Button {
                    Haptics.tap()
                    draft.goal = targetKey
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(isSelected ? Theme.Colors.racingGreen : Theme.Colors.surfaceRaised)
                                .frame(width: 42, height: 42)
                            Image(systemName: item.2)
                                .font(.system(size: 18))
                                .foregroundStyle(isSelected ? Theme.Colors.antiqueBrass : Theme.Colors.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(item.0)
                                    .font(.system(size: 15, weight: .semibold, design: .serif))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                                Text(item.3)
                                    .font(Theme.Fonts.clubTag(9))
                                    .tracking(1.5)
                                    .foregroundStyle(isSelected ? Theme.Colors.antiqueBrass : Theme.Colors.textTertiary)
                            }
                            Text(item.1)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .card()
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius)
                            .strokeBorder(isSelected ? Theme.Colors.racingGreen : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .revealIn(idx + 1)
            }
        }
    }

    // MARK: - Slide 5: The Timepiece Valet (Wearables)

    private var timepieceValetStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("The Timepiece Valet",
                   "SafeFuel synchronizes with your personal chronometer via Apple Health to adjust daily intake when training.",
                   tag: "Smart Chronometer • Step V")
                .revealIn(0)

            let timepieces = [
                ("Apple Watch", "applewatch", "Natively captures active calories, heart rate & workout sessions"),
                ("Fitbit / Google Pixel", "sensor.tag.radiowaves.forward.fill", "Bridges steps, daily strain & cardio exertion via HealthKit"),
                ("Garmin / Whoop / Oura", "waveform.path.ecg", "Synchronizes recovery HRV and high-intensity strain data"),
                ("iPhone Only", "iphone", "Records ambient daily steps and estimated active movement")
            ]

            ForEach(Array(timepieces.enumerated()), id: \.element.0) { idx, w in
                let isSelected = draft.wearable == w.0
                Button {
                    Haptics.tap()
                    draft.wearable = w.0
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(isSelected ? Theme.Colors.racingGreen : Theme.Colors.surfaceRaised)
                                .frame(width: 40, height: 40)
                            Image(systemName: w.1)
                                .font(.system(size: 18))
                                .foregroundStyle(isSelected ? Theme.Colors.antiqueBrass : Theme.Colors.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.0)
                                .font(.system(size: 15, weight: .semibold, design: .serif))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(w.2)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Colors.racingGreen)
                        }
                    }
                    .card()
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius)
                            .strokeBorder(isSelected ? Theme.Colors.racingGreen : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .revealIn(idx + 1)
            }
        }
    }

    // MARK: - Slide 6: The Club Scales (Metrics & BMR)

    private var scalesAndLedgerStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("The Club Balance Scales",
                   "Precision physical metrics used for Mifflin-St Jeor metabolic expenditure calculations.",
                   tag: "Registry Ledger • Step VI")
                .revealIn(0)

            stepperRow("Training frequency", value: $draft.trainingDays, range: 0...7, suffix: " days / wk")
            stepperRow("Weight", value: $draft.weightLb, range: 70...500, suffix: " lb", by: 5)
            stepperRow("Height (ft)", value: $draft.heightFeet, range: 3...7, suffix: "'")
            stepperRow("Height (in)", value: $draft.heightInches, range: 0...11, suffix: "\"")
            stepperRow("Age", value: $draft.age, range: 13...100, suffix: " yrs")

            HStack(spacing: 10) {
                Image(systemName: "scalemass.fill")
                    .foregroundStyle(Theme.Colors.antiqueBrass)
                    .font(.system(size: 16))
                let isFemale = draft.gender == "Female"
                Text(isFemale ? "Calibrated to female basal metabolism (-161 kcal factor) for hormonal and energy balance."
                              : "Calibrated to male basal metabolism (+5 kcal factor) for lean mass synthesis and power.")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(12)
            .background(Theme.Colors.antiqueBrass.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Colors.antiqueBrass.opacity(0.3), lineWidth: 1))
        }
    }

    private func stepperRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>,
                            suffix: String, by: Int = 1) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Button {
                if value.wrappedValue - by >= range.lowerBound {
                    Haptics.tap(); value.wrappedValue -= by
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Colors.racingGreen)
                    .frame(width: 32, height: 32)
                    .background(Theme.Colors.surfaceRaised, in: Circle())
            }
            Text("\(value.wrappedValue)\(suffix)")
                .font(.system(size: 15, weight: .bold, design: .serif).monospacedDigit())
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(minWidth: 68)
            Button {
                if value.wrappedValue + by <= range.upperBound {
                    Haptics.tap(); value.wrappedValue += by
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 32)
                    .background(Theme.Colors.racingGreen, in: Circle())
            }
        }
        .card()
    }

    // MARK: - Slide 7: The Chef's Table (Calculation & Blueprint)

    private var chefsTableStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !calculationComplete {
                engravedCalculatingCard
            } else {
                unfoldingMenuBlueprint
            }
        }
        .task {
            if !calculationComplete {
                runCalculationAnimation()
            }
        }
    }

    private var engravedCalculatingCard: some View {
        VStack(spacing: 22) {
            Spacer().frame(height: 10)

            ZStack {
                Circle()
                    .stroke(Theme.Colors.surfaceRaised, lineWidth: 6)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: calculationProgress)
                    .stroke(Theme.Colors.antiqueBrass, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: calculationProgress)

                VStack(spacing: 1) {
                    Text("\(Int(calculationProgress * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.Colors.racingGreen)
                    Text("CALIBRATING")
                        .font(Theme.Fonts.clubTag(9))
                        .tracking(1.5)
                        .foregroundStyle(Theme.Colors.antiqueBrass)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 6) {
                Text(phaseTitle)
                    .font(Theme.Fonts.display(20))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Applying your quarantine list, \(draft.gender.lowercased()) biology, and \(draft.wearable) synchronization.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                inspectionLine("Larder quarantine matrix screening", done: calculationProgress >= 0.25)
                inspectionLine("\(draft.gender) basal metabolic expenditure calibrated", done: calculationProgress >= 0.50)
                inspectionLine("Chronometer workout strain integration verified", done: calculationProgress >= 0.75)
                inspectionLine("SafeFuel Bespoke Chef Blueprint generated", done: calculationProgress >= 0.98)
            }
            .padding(14)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.Colors.parchmentBorder, lineWidth: 1))
        }
    }

    private func inspectionLine(_ title: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.seal.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(done ? Theme.Colors.racingGreen : Theme.Colors.textTertiary)
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundStyle(done ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
            Spacer()
        }
    }

    private var phaseTitle: String {
        switch calculationPhase {
        case 0: return "Quarantining Ingredients..."
        case 1: return "Calibrating \(draft.gender) Metabolism..."
        case 2: return "Balancing Macronutrient Ledger..."
        default: return "Finalizing Club Blueprint..."
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
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                calculationComplete = true
            }
            Haptics.success()
        }
    }

    private var unfoldingMenuBlueprint: some View {
        let t = draft.targets
        let isFemale = draft.gender == "Female"
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(draft.gender.uppercased()) FUEL BLUEPRINT LOCKED")
                    .font(Theme.Fonts.clubTag(10))
                    .tracking(2.0)
                    .foregroundStyle(Theme.Colors.antiqueBrass)
                Spacer()
                WaxSealStamp(text: "SEALED", size: 24, color: Theme.Colors.racingGreen)
            }

            header("Your Daily Nutrition Ledger",
                   "Formulated for \(draft.goal.lowercased()), \(draft.gender.lowercased()) physiology, and \(draft.trainingDays) training days per week.")

            // Four Ledger Tiles
            HStack(spacing: 8) {
                ledgerTile(t.calories.formatted(.number.grouping(.automatic)), "calories", Theme.Colors.racingGreen)
                ledgerTile("\(t.protein)g", "protein", Theme.Colors.protein)
                ledgerTile("\(t.carbs)g", "carbs", Theme.Colors.carbs)
                ledgerTile("\(t.fat)g", "fat", Theme.Colors.fat)
            }

            // Allergen Shield Card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(Theme.Colors.safe)
                    Text("Pantry Quarantine Protocol Active")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                let activeAllergens = Array(draft.allergenNames.filter { !$0.contains("No Allergens") })
                Text(activeAllergens.isEmpty ? "All provisions cleared for standard culinary logging."
                                             : activeAllergens.sorted().joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .card()

            // Micronutrient Shield Card
            HStack(spacing: 10) {
                Image(systemName: isFemale ? "heart.circle.fill" : "bolt.circle.fill")
                    .foregroundStyle(Theme.Colors.antiqueBrass)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text(isFemale ? "Lady's Micronutrient Protocol" : "Gentleman's Power Protocol")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(isFemale ? "Iron & Calcium prioritized for bone density and sustained stamina."
                                  : "Zinc & Magnesium prioritized for lean mass synthesis and power.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(12)
            .background(Theme.Colors.antiqueBrass.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.Colors.antiqueBrass.opacity(0.3), lineWidth: 1))
        }
    }

    private func ledgerTile(_ val: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(val)
                .font(.system(size: 17, weight: .bold, design: .serif).monospacedDigit())
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(Theme.Fonts.clubTag(9))
                .tracking(1.0)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Colors.parchmentBorder, lineWidth: 1))
    }

    // MARK: - Slide 8: The Member Registry (Account Creation)

    private var memberRegistryStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("The Club Registry",
                   "Inscribe your name in the club roll to secure your blueprint, quarantine list, and chronometer history.",
                   tag: "Registry Enrollment • Step VIII")

            if let authErrorMessage {
                Text(authErrorMessage)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.danger)
                    .padding(10)
                    .background(Theme.Colors.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            }

            VStack(spacing: 12) {
                // Sign in with Apple
                SignInWithAppleButton(isSigningUp ? .signUp : .signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task { await handleApple(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Colors.parchmentBorder, lineWidth: 1))
                }
                .pressable()
                .disabled(authBusy)

                HStack {
                    Rectangle().fill(Theme.Colors.parchmentBorder).frame(height: 1)
                    Text("or with email").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textTertiary)
                    Rectangle().fill(Theme.Colors.parchmentBorder).frame(height: 1)
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
                            ProgressView().tint(Color.white)
                        } else {
                            Text(isSigningUp ? "Inscribe & Proceed" : "Sign In & Proceed")
                                .font(Theme.Fonts.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.Colors.racingGreen)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Colors.antiqueBrass.opacity(0.35), lineWidth: 1))
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
                    Text(isSigningUp ? "Already enrolled in registry? Sign in" : "New member? Enroll an account")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.racingGreen)
                }

                Divider().padding(.top, 4)

                Button {
                    Haptics.tap()
                    session.isDemo = true
                    isMovingForward = true
                    withAnimation { step = 9 }
                } label: {
                    Text("Enter on Guest Pass / Skip for now")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
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
