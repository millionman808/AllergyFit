import SwiftUI

/// Hands-free cook mode — one step per screen, big and glanceable from across
/// the kitchen. Progress dots, Next/Back, and a peek at the ingredient list.
/// Mirrors the Mealime-style flow from the reference set.
struct CookModeView: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe

    @State private var step = 0
    @State private var showIngredients = false

    // Timer — a labeled countdown that floats on screen and keeps running as
    // you move between steps.
    @State private var secondsLeft = 0
    @State private var timerActive = false
    @State private var timerDone = false
    @State private var timerLabel = ""
    @State private var showTimerSetup = false
    @State private var setupMinutes = 10
    @State private var setupLabel = ""
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var steps: [String] { recipe.steps }
    private var isLast: Bool { step >= steps.count - 1 }
    private var stepMinutes: Int? { CookModeView.detectMinutes(steps.indices.contains(step) ? steps[step] : "") }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Top bar: close + recipe title
                HStack {
                    Text(recipe.title)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Button { Haptics.tap(); dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(width: 34, height: 34)
                            .background(Theme.Colors.surface, in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                timerPill   // floats here, always visible while a timer runs

                // The step — the whole point, oversized
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Step \(step + 1) of \(steps.count)")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.volt)
                        Text("\(step + 1)")
                            .font(Theme.Fonts.stat(64))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(steps.indices.contains(step) ? steps[step] : "")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }

                // Progress dots
                HStack(spacing: 6) {
                    ForEach(steps.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? Theme.Colors.volt : Theme.Colors.surfaceRaised)
                            .frame(width: i == step ? 22 : 7, height: 7)
                            .animation(.spring(response: 0.3), value: step)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)

                timerStrip

                // Controls: ingredients peek · Back · Next/Done
                HStack(spacing: 12) {
                    Button { showIngredients = true } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(width: 54, height: 54)
                            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    if step > 0 {
                        Button { Haptics.tap(); withAnimation { step -= 1 } } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .frame(width: 54, height: 54)
                                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    Button {
                        if isLast {
                            Haptics.success(); dismiss()
                        } else {
                            Haptics.tap(); withAnimation { step += 1 }
                        }
                    } label: {
                        Text(isLast ? "Done cooking" : "Next")
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.onVolt)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .pressable()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showIngredients) {
            ingredientSheet
        }
        .onReceive(ticker) { _ in
            guard timerActive else { return }
            if secondsLeft > 1 {
                secondsLeft -= 1
            } else {
                secondsLeft = 0
                withAnimation { timerActive = false; timerDone = true }
                Haptics.warning()   // buzz when the timer finishes
            }
        }
        .sheet(isPresented: $showTimerSetup) { timerSetupSheet }
    }

    // MARK: Timer

    /// The always-visible countdown. Once started it keeps running as you move
    /// between steps, so you can glance at it any time.
    @ViewBuilder private var timerPill: some View {
        if timerActive || timerDone {
            HStack(spacing: 10) {
                Image(systemName: timerDone ? "bell.fill" : "timer")
                    .font(.headline)
                    .foregroundStyle(timerDone ? Theme.Colors.onVolt : Theme.Colors.volt)
                VStack(alignment: .leading, spacing: 0) {
                    if !timerLabel.isEmpty {
                        Text(timerLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(timerDone ? Theme.Colors.onVolt.opacity(0.9) : Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    Text(timerDone ? "Time's up!" : timeString(secondsLeft))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(timerDone ? Theme.Colors.onVolt : Theme.Colors.textPrimary)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 8)
                Button { withAnimation { stopTimer() } } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(timerDone ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(timerDone ? Color.white.opacity(0.22) : Theme.Colors.surfaceRaised, in: Circle())
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(timerDone ? Theme.Colors.volt : Theme.Colors.surface,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .padding(.horizontal, 20).padding(.top, 10)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// The "set a timer" trigger, shown in the controls column when idle.
    @ViewBuilder private var timerStrip: some View {
        if !timerActive && !timerDone {
            Button {
                setupMinutes = stepMinutes ?? 10
                setupLabel = ""
                showTimerSetup = true
            } label: {
                Label(stepMinutes != nil ? "Set timer · \(stepMinutes!) min" : "Set a timer",
                      systemImage: "timer")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.volt)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.Colors.volt.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .pressable()
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }

    private var timerSetupSheet: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    TextField("What's it for?  (e.g. Rice)", text: $setupLabel)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(14)
                        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Picker("Minutes", selection: $setupMinutes) {
                        ForEach(1...120, id: \.self) { m in Text("\(m) min").tag(m) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxHeight: 150)
                    Button { startTimer() } label: {
                        Text("Start timer")
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.onVolt)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .pressable()
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("New timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showTimerSetup = false } } }
            .presentationDetents([.medium])
        }
    }

    private func startTimer() {
        secondsLeft = max(1, setupMinutes) * 60
        timerLabel = setupLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        timerDone = false
        withAnimation { timerActive = true }
        showTimerSetup = false
        Haptics.tap()
    }

    private func stopTimer() {
        timerActive = false
        timerDone = false
        secondsLeft = 0
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Pulls the first "N min(ute)" duration out of a step, if any (1–240 min).
    static func detectMinutes(_ text: String) -> Int? {
        let lower = text.lowercased()
        let pattern = #"(\d{1,3})\s*(?:to|-|–)?\s*\d{0,3}\s*(?:min|minute)"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
              let r = Range(m.range(at: 1), in: lower),
              let n = Int(lower[r]), (1...240).contains(n) else { return nil }
        return n
    }

    private var ingredientSheet: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(recipe.ingredients, id: \.self) { ing in
                            HStack(alignment: .top, spacing: 10) {
                                Circle().fill(Theme.Colors.volt).frame(width: 6, height: 6).padding(.top, 8)
                                Text(ing)
                                    .font(Theme.Fonts.body)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
            }
            .navigationTitle("Ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
        }
    }
}
