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

    private let totalSteps = 4

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
        Button {
            if step < totalSteps - 1 {
                withAnimation { step += 1 }
            } else {
                withAnimation { session.demoOnboarded = true }
            }
        } label: {
            Text(step == totalSteps - 1 ? "Start Training" : "Continue")
                .font(Theme.Fonts.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Theme.Colors.volt)
                .foregroundStyle(Theme.Colors.onVolt)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

                VStack(spacing: 4) {
                    Text("2,840")
                        .font(Theme.Fonts.stat(64))
                        .foregroundStyle(Theme.Colors.volt)
                    Text("calories on training days")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("2,540 on rest days")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .card()

                HStack(spacing: Theme.Metrics.spacing) {
                    targetPill("Protein", "180g", Theme.Colors.protein)
                    targetPill("Carbs", "320g", Theme.Colors.carbs)
                    targetPill("Fat", "84g", Theme.Colors.fat)
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
