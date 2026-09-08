import SwiftUI

/// The pre-account funnel. People answer for themselves and see their real
/// numbers BEFORE being asked to sign up — so the account is the last small
/// step, not the first big one.
struct PreAuthOnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Called when the funnel finishes (or is skipped) → show AuthView.
    var onFinish: () -> Void

    @State private var step = 0
    @State private var draft = OnboardingDraft.stored ?? OnboardingDraft()

    private let total = 7
    private let allAllergens = MockData.allAllergens

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        content
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                    .id(step)
                    .transition(.onboardingStep)
                }
                .animation(reduceMotion ? .easeOut(duration: 0.15)
                                        : .spring(response: 0.5, dampingFraction: 0.88), value: step)
                footer
            }
        }
    }

    // MARK: Chrome

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

            Button("Sign in") { finish() }
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button { advance() } label: {
                Text(step == total - 1 ? "Create my account" : "Continue")
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
        step == 1 ? !draft.allergenNames.isEmpty : true
    }

    private func advance() {
        Haptics.tap()
        if step == total - 1 { finish(); return }
        withAnimation { step += 1 }
        draft.save()
    }
    private func back() {
        Haptics.tap()
        withAnimation { step -= 1 }
    }
    private func finish() {
        draft.save()
        UserDefaults.standard.set(true, forKey: "seenPreAuthOnboarding")
        onFinish()
    }

    // MARK: Steps

    @ViewBuilder private var content: some View {
        switch step {
        case 0: welcomeStep
        case 1: triggersStep
        case 2: severityStep
        case 3: goalStep
        case 4: statsStep
        case 5: trustStep
        default: payoffStep
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

    // 0 — the promise
    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                Circle().fill(Theme.Colors.volt).frame(width: 78, height: 78)
                    .shadow(color: Theme.Colors.volt.opacity(0.45), radius: 18, y: 6)
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.Colors.onVolt)
            }
            .padding(.top, 20)
            .revealIn(0)
            header("Train hard.\nEat safe.",
                   "The nutrition app for people with food allergies who train.")
                .revealIn(1)
            VStack(alignment: .leading, spacing: 12) {
                bullet("checkmark.shield.fill", "Every meal checked against your triggers").revealIn(2)
                bullet("chart.bar.fill", "Macros from the USDA database — never guessed").revealIn(3)
                bullet("calendar", "A week of safe meals, planned for you").revealIn(4)
            }
            .padding(.top, 4)
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

    // 1 — triggers
    private var triggersStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("What do you need to avoid?",
                   "Pick everything that applies. You can change this any time.")
                .revealIn(0)
            FlowChips(items: allAllergens, selected: $draft.allergenNames)
                .revealIn(1)
        }
    }

    // 2 — severity
    private var severityStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("How bad is each one?",
                   "This decides how hard we flag a food — a trace of something anaphylactic isn't the same as a little dairy.")
                .revealIn(0)
            ForEach(Array(Array(draft.allergenNames).sorted().enumerated()), id: \.element) { idx, name in
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
    private func selected(_ name: String) -> Sensitivity {
        Sensitivity(rawValue: draft.severityByName[name] ?? "moderate") ?? .moderate
    }

    // 3 — goal
    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("What are you training for?",
                   "We'll set your calories and protein around it.")
                .revealIn(0)
            ForEach(Array(["Build muscle", "Maintain", "Cut"].enumerated()), id: \.element) { idx, g in
                Button {
                    Haptics.tap(); draft.goal = g
                } label: {
                    HStack {
                        Text(g)
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Image(systemName: draft.goal == g ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(draft.goal == g ? Theme.Colors.volt : Theme.Colors.textTertiary)
                    }
                    .card()
                }
                .buttonStyle(.plain)
                .revealIn(idx + 1)
            }
        }
    }

    // 4 — stats
    private var statsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("A few numbers",
                   "So your targets are actually yours.")
            stepper("Training days / week", value: $draft.trainingDays, range: 0...7, suffix: "")
            stepper("Weight", value: $draft.weightLb, range: 70...500, suffix: " lb", by: 5)
            stepper("Height (ft)", value: $draft.heightFeet, range: 3...7, suffix: "'")
            stepper("Height (in)", value: $draft.heightInches, range: 0...11, suffix: "\"")
            stepper("Age", value: $draft.age, range: 13...100, suffix: "")
        }
    }

    private func stepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>,
                         suffix: String, by: Int = 1) -> some View {
        HStack {
            Text(label).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Button { if value.wrappedValue - by >= range.lowerBound { Haptics.tap(); value.wrappedValue -= by } } label: {
                Image(systemName: "minus").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Theme.Colors.surfaceRaised, in: Circle())
            }
            Text("\(value.wrappedValue)\(suffix)")
                .font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                .frame(minWidth: 62)
            Button { if value.wrappedValue + by <= range.upperBound { Haptics.tap(); value.wrappedValue += by } } label: {
                Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.onVolt)
                    .frame(width: 34, height: 34)
                    .background(Theme.Colors.volt, in: Circle())
            }
        }
        .card()
    }

    // 5 — the trust screen (our differentiator)
    private var trustStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            header("We never invent your numbers.",
                   "Other AI food apps guess the calories. We don't.")
            VStack(alignment: .leading, spacing: 14) {
                trustRow("1", "You snap a photo",
                         "The AI only identifies what's on the plate.").revealIn(1)
                trustRow("2", "USDA supplies the numbers",
                         "Every calorie and gram comes from the official food database.").revealIn(2)
                trustRow("3", "We check it against you",
                         "Then flag anything containing one of your triggers.").revealIn(3)
            }
            Text("Always read the physical label too — recipes change and databases lag behind.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func trustRow(_ n: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(n)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.onVolt)
                .frame(width: 28, height: 28)
                .background(Theme.Colors.volt, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                Text(body).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // 6 — payoff, then account
    private var payoffStep: some View {
        let t = draft.targets
        return VStack(alignment: .leading, spacing: 20) {
            header("Your plan is ready.",
                   "Based on your goal, your body and \(draft.allergenNames.count) trigger\(draft.allergenNames.count == 1 ? "" : "s").")
            HStack(spacing: 10) {
                target("\(t.calories)", "calories", Theme.Colors.volt).scatterIn(0)
                target("\(t.protein)g", "protein", Theme.Colors.protein).scatterIn(1)
                target("\(t.carbs)g", "carbs", Theme.Colors.carbs).scatterIn(2)
                target("\(t.fat)g", "fat", Theme.Colors.fat).scatterIn(3)
            }
            if !draft.allergenNames.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("We'll screen every meal for", systemImage: "checkmark.shield.fill")
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.safe)
                    Text(Array(draft.allergenNames).sorted().joined(separator: " · "))
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            Text("Create a free account to save this and start logging.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }

    private func target(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 3) {
            Text(v).font(Theme.Fonts.stat(21)).foregroundStyle(c)
            Text(l).font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
