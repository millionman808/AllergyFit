import SwiftUI

/// Reaction-learning insights — the moat, visualized.
struct InsightsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                        headline
                        ForEach(MockData.patterns) { pattern in
                            PatternCard(pattern: pattern)
                        }
                        nutrientGaps
                        weeklyCard
                    }
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Insights")
        }
    }

    private var headline: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.title3)
                .foregroundStyle(Theme.Colors.volt)
            Text("3 patterns detected from 42 meals, 18 workouts, and 9 check-ins")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
        }
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
                statBox("5", "workouts", "dumbbell.fill")
                statBox("92%", "plan adherence", "checkmark.circle.fill")
                statBox("0", "reactions", "shield.fill")
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
    let pattern: DemoPattern

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

            Text("You reported \(pattern.symptom.lowercased()) \(pattern.occurrences) of the last \(pattern.exposures) times you ate this \(pattern.windowText).")
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
                Button {
                } label: {
                    Text("Remove from plans")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.onVolt)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.volt, in: Capsule())
                }
                Button {
                } label: {
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
