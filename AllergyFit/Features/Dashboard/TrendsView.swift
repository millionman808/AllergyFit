import SwiftUI
import Charts
import Supabase

// MARK: - Store

struct DayNutrition: Identifiable, Equatable {
    var id: Date { day }
    let day: Date
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
}

/// Loads the last N days of meal history and aggregates per-day totals for the
/// dashboard trend graphs. Demo mode uses generated sample data.
@MainActor
final class TrendsStore: ObservableObject {
    @Published var days: [DayNutrition] = []
    @Published var targetCalories = 2840
    @Published var isLoading = false

    private var isDemo = false
    private var userId: UUID?
    private var configured = false
    let window = 14

    func configure(session: SessionStore, targetCalories: Int) {
        self.targetCalories = targetCalories
        guard !configured else { return }
        configured = true
        isDemo = session.isDemo
        userId = session.session?.user.id
        if isDemo {
            days = Self.mock()
        } else {
            Task { await refresh() }
        }
    }

    func refresh() async {
        guard !isDemo, let userId else { return }
        isLoading = true
        defer { isLoading = false }
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(window - 1), to: cal.startOfDay(for: Date()))!
        do {
            let records: [MealLogRecord] = try await Backend.client
                .from("meal_logs")
                .select("id, user_id, eaten_at, meal_type, name, calories, protein_g, carbs_g, fat_g")
                .eq("user_id", value: userId)
                .gte("eaten_at", value: start.ISO8601Format())
                .order("eaten_at", ascending: true)
                .execute()
                .value
            days = Self.aggregate(records, from: start, window: window)
        } catch {
            print("trends fetch failed: \(error)")
        }
    }

    /// Zero-fill every day in the window so the chart always shows N points.
    static func aggregate(_ records: [MealLogRecord], from start: Date, window: Int) -> [DayNutrition] {
        let cal = Calendar.current
        var map: [Date: DayNutrition] = [:]
        for i in 0..<window {
            let d = cal.date(byAdding: .day, value: i, to: start)!
            map[d] = DayNutrition(day: d, calories: 0, protein: 0, carbs: 0, fat: 0)
        }
        for r in records {
            let d = cal.startOfDay(for: r.eatenAt)
            guard var day = map[d] else { continue }
            day.calories += r.calories ?? 0
            day.protein += Int(r.proteinG ?? 0)
            day.carbs += Int(r.carbsG ?? 0)
            day.fat += Int(r.fatG ?? 0)
            map[d] = day
        }
        return map.values.sorted { $0.day < $1.day }
    }

    static func mock() -> [DayNutrition] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -13, to: cal.startOfDay(for: Date()))!
        return (0..<14).map { i in
            DayNutrition(
                day: cal.date(byAdding: .day, value: i, to: start)!,
                calories: 2200 + Int.random(in: -400...600),
                protein: 120 + Int.random(in: -30...60),
                carbs: 240 + Int.random(in: -60...80),
                fat: 70 + Int.random(in: -20...30)
            )
        }
    }

    // MARK: Derived

    var loggedDays: [DayNutrition] { days.filter { $0.calories > 0 } }
    var hasData: Bool { !loggedDays.isEmpty }
    private func avg(_ key: (DayNutrition) -> Int) -> Int {
        loggedDays.isEmpty ? 0 : loggedDays.reduce(0) { $0 + key($1) } / loggedDays.count
    }
    var avgCalories: Int { avg { $0.calories } }
    var avgProtein: Int { avg { $0.protein } }
    var avgCarbs: Int { avg { $0.carbs } }
    var avgFat: Int { avg { $0.fat } }
}

// MARK: - Home-screen card (the tappable graph preview)

struct TrendsCard: View {
    @ObservedObject var store: TrendsStore
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.onVolt)
                        .frame(width: 34, height: 34)
                        .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Trends")
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(store.hasData ? "\(store.avgCalories) kcal avg · last 14 days" : "Log meals to see your trends")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                // Live mini sparkline of calories
                Chart(store.days) { d in
                    AreaMark(
                        x: .value("Day", d.day),
                        y: .value("Calories", d.calories)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Theme.Colors.volt.opacity(0.45), Theme.Colors.volt.opacity(0.03)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Day", d.day),
                        y: .value("Calories", d.calories)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.Colors.volt)
                    .lineStyle(.init(lineWidth: 2))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 56)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Full graphs sheet

struct TrendsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TrendsStore

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                        if !store.hasData {
                            emptyState
                        } else {
                            summaryRow
                            caloriesChart
                            proteinChart
                            macroBalanceChart
                        }
                    }
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.bottom, 24)
                }
                .refreshable { await store.refresh() }
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.Colors.volt)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("No data yet")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Log a few meals and your calorie and macro trends will show up here.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .card()
    }

    private var summaryRow: some View {
        HStack(spacing: Theme.Metrics.spacing) {
            summaryBox("\(store.avgCalories)", "avg kcal", Theme.Colors.volt)
            summaryBox("\(store.avgProtein)g", "avg protein", Theme.Colors.protein)
            summaryBox("\(store.loggedDays.count)", "days logged", Theme.Colors.textPrimary)
        }
        .padding(.top, 4)
    }

    private func summaryBox(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.Fonts.stat(22))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private var caloriesChart: some View {
        chartCard(title: "Calories", subtitle: "Daily total vs your \(store.targetCalories) target") {
            Chart {
                ForEach(store.days) { d in
                    BarMark(
                        x: .value("Day", d.day, unit: .day),
                        y: .value("Calories", d.calories)
                    )
                    .foregroundStyle(Theme.Colors.volt.gradient)
                    .cornerRadius(4)
                }
                RuleMark(y: .value("Target", store.targetCalories))
                    .lineStyle(.init(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Target")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Theme.Colors.surfaceRaised)
                    AxisValueLabel { valueText(value.as(Int.self)) }
                }
            }
            .chartXAxis { dayAxis }
            .frame(height: 180)
        }
    }

    private var proteinChart: some View {
        chartCard(title: "Protein", subtitle: "Grams per day") {
            Chart(store.days) { d in
                AreaMark(
                    x: .value("Day", d.day, unit: .day),
                    y: .value("Protein", d.protein)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    .linearGradient(colors: [Theme.Colors.protein.opacity(0.4), Theme.Colors.protein.opacity(0.02)],
                                    startPoint: .top, endPoint: .bottom)
                )
                LineMark(
                    x: .value("Day", d.day, unit: .day),
                    y: .value("Protein", d.protein)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Theme.Colors.protein)
                .lineStyle(.init(lineWidth: 2.5))
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Theme.Colors.surfaceRaised)
                    AxisValueLabel { valueText(value.as(Int.self)) }
                }
            }
            .chartXAxis { dayAxis }
            .frame(height: 160)
        }
    }

    private var macroBalanceChart: some View {
        chartCard(title: "Average macro balance", subtitle: "Grams per day, last 14 days") {
            Chart {
                macroBar("Protein", store.avgProtein, Theme.Colors.protein)
                macroBar("Carbs", store.avgCarbs, Theme.Colors.carbs)
                macroBar("Fat", store.avgFat, Theme.Colors.fat)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Theme.Colors.surfaceRaised)
                    AxisValueLabel()
                }
            }
            .frame(height: 150)
        }
    }

    private func macroBar(_ name: String, _ grams: Int, _ color: Color) -> some ChartContent {
        BarMark(
            x: .value("Grams", grams),
            y: .value("Macro", name)
        )
        .foregroundStyle(color.gradient)
        .cornerRadius(5)
        .annotation(position: .trailing) {
            Text("\(grams)g")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // Shared axis: one label every ~3 days
    private var dayAxis: some AxisContent {
        AxisMarks(values: .stride(by: .day, count: 3)) { value in
            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }

    @ViewBuilder
    private func valueText(_ v: Int?) -> some View {
        if let v { Text("\(v)").foregroundStyle(Theme.Colors.textTertiary) }
    }

    private func chartCard<Content: View>(title: String, subtitle: String,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(subtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            content()
        }
        .card()
    }
}
