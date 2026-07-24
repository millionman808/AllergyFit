import Foundation
import Supabase

/// Saves workouts + symptom check-ins to Supabase and runs the correlation engine.
enum LogService {
    static func workoutSlug(_ display: String) -> String {
        switch display {
        case "Lifting": return "lifting"
        case "Running": return "running"
        case "CrossFit": return "crossfit"
        case "Cycling": return "cycling"
        case "Swimming": return "swimming"
        case "HIIT": return "hiit"
        case "Team sport": return "team_sport"
        case "Yoga": return "yoga"
        default: return "other"
        }
    }

    static func symptomSlug(_ display: String) -> String {
        switch display {
        case "Hives": return "hives"
        case "Itching": return "itching"
        case "GI distress": return "gi_distress"
        case "Nausea": return "nausea"
        case "Bloating": return "bloating"
        case "Fatigue": return "fatigue"
        case "Headache": return "headache"
        case "Congestion": return "congestion"
        case "Swelling": return "swelling"
        case "Breathing": return "breathing"
        case "Skin flush": return "skin_flush"
        case "Dizziness": return "dizziness"
        default: return "other"
        }
    }

    static func saveWorkout(userId: UUID, type: String, minutes: Int, intensity: String) async throws {
        struct Row: Codable {
            let user_id: UUID
            let workout_type: String
            let duration_minutes: Int
            let intensity: String
        }
        let row = Row(user_id: userId, workout_type: workoutSlug(type),
                      duration_minutes: minutes, intensity: intensity.lowercased())
        try await Backend.client.from("workouts").insert(row).execute()
    }

    static func saveSymptom(userId: UUID, symptoms: [String], severity: String,
                            duringExercise: Bool, notes: String? = nil) async throws {
        struct Row: Codable {
            let user_id: UUID
            let symptoms: [String]
            let severity: String
            let during_or_after_exercise: Bool
            let notes: String?
        }
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let row = Row(user_id: userId, symptoms: symptoms.map(symptomSlug),
                      severity: severity.lowercased(), during_or_after_exercise: duringExercise,
                      notes: (trimmed?.isEmpty == false) ? trimmed : nil)
        try await Backend.client.from("symptom_logs").insert(row).execute()

        // Re-run the time-window correlation engine so Insights stays current.
        struct Params: Encodable { let p_user_id: UUID; let p_window_minutes: Int }
        _ = try? await Backend.client
            .rpc("detect_reaction_patterns", params: Params(p_user_id: userId, p_window_minutes: 180))
            .execute()
    }
}
