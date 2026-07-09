import Foundation
import Supabase

struct InsightPattern: Identifiable, Equatable {
    let id: UUID
    var ingredient: String
    var symptom: String
    var occurrences: Int
    var exposures: Int
    var windowMinutes: Int
    var exerciseLinked: Bool
    var confidence: Double

    var windowText: String {
        exerciseLinked ? "within \(windowMinutes) min of exercise" : "within \(windowMinutes / 60) hours"
    }
    var symptomLabel: String {
        symptom.replacingOccurrences(of: "_", with: " ")
    }
}

@MainActor
final class InsightsStore: ObservableObject {
    @Published var patterns: [InsightPattern] = []
    @Published var mealCount = 0
    @Published var workoutCount = 0
    @Published var checkinCount = 0
    @Published var isLoading = false

    private var isDemo = true
    private var userId: UUID?
    private var configured = false

    func configure(session: SessionStore) {
        guard !configured else { return }
        configured = true
        isDemo = session.isDemo
        userId = session.session?.user.id
        if isDemo {
            patterns = MockData.patterns.map {
                InsightPattern(id: UUID(), ingredient: $0.ingredient,
                               symptom: $0.symptom.lowercased(), occurrences: $0.occurrences,
                               exposures: $0.exposures, windowMinutes: $0.exerciseLinked ? 90 : 180,
                               exerciseLinked: $0.exerciseLinked, confidence: $0.confidence)
            }
            mealCount = 42; workoutCount = 18; checkinCount = 9
        } else {
            Task { await refresh() }
        }
    }

    func refresh() async {
        guard !isDemo, let userId else { return }
        isLoading = true
        defer { isLoading = false }
        struct PRow: Codable {
            let id: UUID
            let ingredient: String
            let symptom: String
            let occurrenceCount: Int
            let exposureCount: Int
            let windowMinutes: Int
            let exerciseLinked: Bool
            let confidence: Double?
            enum CodingKeys: String, CodingKey {
                case id, ingredient, symptom
                case occurrenceCount = "occurrence_count"
                case exposureCount = "exposure_count"
                case windowMinutes = "window_minutes"
                case exerciseLinked = "exercise_linked"
                case confidence
            }
        }
        do {
            let rows: [PRow] = try await Backend.client
                .from("reaction_patterns")
                .select("id, ingredient, symptom, occurrence_count, exposure_count, window_minutes, exercise_linked, confidence")
                .eq("user_id", value: userId)
                .eq("dismissed", value: false)
                .order("confidence", ascending: false)
                .execute().value
            patterns = rows.map {
                InsightPattern(id: $0.id, ingredient: $0.ingredient, symptom: $0.symptom,
                               occurrences: $0.occurrenceCount, exposures: $0.exposureCount,
                               windowMinutes: $0.windowMinutes, exerciseLinked: $0.exerciseLinked,
                               confidence: $0.confidence ?? 0)
            }
            mealCount = try await count("meal_logs", userId)
            workoutCount = try await count("workouts", userId)
            checkinCount = try await count("symptom_logs", userId)
        } catch {
            print("insights load failed: \(error)")
        }
    }

    private func count(_ table: String, _ userId: UUID) async throws -> Int {
        let res = try await Backend.client.from(table)
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId)
            .execute()
        return res.count ?? 0
    }

    func dismiss(_ pattern: InsightPattern) {
        patterns.removeAll { $0.id == pattern.id }
        guard !isDemo else { return }
        Task {
            struct Upd: Codable { let dismissed: Bool }
            try? await Backend.client.from("reaction_patterns")
                .update(Upd(dismissed: true)).eq("id", value: pattern.id).execute()
        }
    }
}
