import SwiftUI

/// Reaction-learning insights — the moat, visualized. Backed by InsightsStore.
struct InsightsView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var store = InsightsStore()
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                        headline
                        if store.patterns.isEmpty {
                            emptyState
                        } else {
                            ForEach(store.patterns) { pattern in
                                PatternCard(
                                    pattern: pattern,
                                    onRemove: {
                                        toastThen("We'll keep \(pattern.ingredient.lowercased()) out of your meal plans")
                                        store.dismiss(pattern)
                                    },
                                    onDismiss: { store.dismiss(pattern) }
                                )
                            }
                        }
                        nutrientGaps
                        weeklyCard
                    }
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.bottom, 24)
                }
                .refreshable { await store.refresh() }

                if let toast {
                    VStack {
                        Spacer()
                        Label(toast, systemImage: "checkmark.circle.fill")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.onVolt)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(Theme.Colors.volt, in: Capsule())
                            .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Insights")
            .onAppear { store.configure(session: session) }
        }
    }

    private func toastThen(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { toast = nil }
        }
    }

    private var headline: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.title3)
                .foregroundStyle(Theme.Colors.volt)
            Text("\(store.patterns.count) pattern\(store.patterns.count == 1 ? "" : "s") detected from \(store.mealCount) meals, \(store.workoutCount) workouts, and \(store.checkinCount) check-ins")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
        }
        .card()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("No patterns yet")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Log meals, workouts, and symptom check-ins — AllergyFit learns what sets you off and surfaces it here.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .card()
    }

    private var nutrientGaps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition gaps")
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.top, 8)
            gapRow("Calcium", "62% of target — common on dairy-free diets", "Try: fortified oat milk, kale, sardines")
            gapRow("Vitamin D", "48% of target", "Try: salmon, fortified cereal, sunlight")
        }
    }

    private func gapRow(_ nutrient: String, _ status: String, _ fix: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(nutrient)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.caution)
            }
            Text(status)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(fix)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.volt)
        }
        .card()
    }

    private var weeklyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week")
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.top, 8)
            HStack(spacing: Theme.Metrics.spacing) {
                statBox("\(store.workoutCount)", "workouts", "dumbbell.fill")
                statBox("92%", "plan adherence", "checkmark.circle.fill")
                statBox("\(store.checkinCount)", "check-ins", "heart.text.square.fill")
            }
        }
    }

    private func statBox(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.Colors.volt)
            Text(value)
                .font(Theme.Fonts.stat(24))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}

struct PatternCard: View {
    let pattern: InsightPattern
    let onRemove: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: pattern.exerciseLinked ? "bolt.heart.fill" : "exclamationmark.magnifyingglass")
                    .foregroundStyle(confidenceColor)
                Text(pattern.ingredient)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                if pattern.exerciseLinked {
                    Text("EXERCISE-LINKED")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.onVolt)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.caution, in: Capsule())
                }
            }

            Text("You reported \(pattern.symptomLabel) \(pattern.occurrences) of the last \(pattern.exposures) times you ate this \(pattern.windowText).")
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Colors.surfaceRaised)
                        Capsule()
                            .fill(confidenceColor)
                            .frame(width: geo.size.width * pattern.confidence)
                    }
                }
                .frame(height: 6)
                Text("\(Int(pattern.confidence * 100))%")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(confidenceColor)
            }

            HStack(spacing: 10) {
                Button(action: onRemove) {
                    Text("Remove from plans")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.onVolt)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.volt, in: Capsule())
                }
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.surfaceRaised, in: Capsule())
                }
            }
        }
        .card()
    }

    private var confidenceColor: Color {
        if pattern.confidence >= 0.7 { return Theme.Colors.danger }
        if pattern.confidence >= 0.5 { return Theme.Colors.caution }
        return Theme.Colors.textSecondary
    }
}
