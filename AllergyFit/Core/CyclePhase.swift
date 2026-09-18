import Foundation
import SwiftUI

/// The four distinct hormonal phases of the female athletic cycle.
enum CyclePhase: String, CaseIterable, Codable, Identifiable {
    case menstrual = "Menstrual"
    case follicular = "Follicular"
    case ovulatory = "Ovulatory"
    case luteal = "Luteal"

    var id: String { rawValue }

    var title: String { rawValue }

    var dayRangeDescription: String {
        switch self {
        case .menstrual: return "Days 1–5"
        case .follicular: return "Days 6–13"
        case .ovulatory: return "Days 14–16"
        case .luteal: return "Days 17–28"
        }
    }

    /// Scientific caloric adjustment based on progesterone-driven BMR elevation.
    var caloricAdjustment: Int {
        switch self {
        case .luteal: return 150
        default: return 0
        }
    }

    /// Additional protein to guard against progesterone-induced muscle catabolism.
    var proteinAdjustment: Int {
        switch self {
        case .luteal: return 5
        default: return 0
        }
    }

    /// Evidence-based athletic nutrition guidance.
    var coachingSummary: String {
        switch self {
        case .menstrual:
            return "Prioritize iron replenishment, electrolytes, and restorative fuel to combat uterine fatigue."
        case .follicular:
            return "High insulin sensitivity and optimal glycogen uptake. Prime for heavy compound lifting and carbohydrate utilization."
        case .ovulatory:
            return "Estrogen peak. Maximum strength output, tendon elasticity awareness, and peak neuromuscular power."
        case .luteal:
            return "Progesterone elevates resting metabolic rate (+150 kcal). Protein intake boosted to preserve lean muscle and prevent craving crashes."
        }
    }

    var icon: String {
        switch self {
        case .menstrual: return "drop.fill"
        case .follicular: return "leaf.fill"
        case .ovulatory: return "sparkles"
        case .luteal: return "flame.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .menstrual: return Color(hex: 0x9B1D20) // Sealing wax red
        case .follicular: return Color(hex: 0x143424) // British racing green
        case .ovulatory: return Color(hex: 0xC5A059) // Burnished brass
        case .luteal: return Color(hex: 0x7E4924) // Saddle leather / amber
        }
    }
}

/// Persistent state of the member's cycle preferences.
struct CycleState: Codable {
    var isEnabled: Bool = false
    var cycleLengthDays: Int = 28
    var lastPeriodStartDate: Date = Calendar.current.date(byAdding: .day, value: -18, to: Date()) ?? Date()
    var manualOverridePhase: CyclePhase? = nil

    /// Computes the current cycle day (1...cycleLengthDays) based on the start date.
    func currentDay(on date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: date)
        let startOfPeriod = calendar.startOfDay(for: lastPeriodStartDate)
        let diff = calendar.dateComponents([.day], from: startOfPeriod, to: startOfToday).day ?? 0
        if diff < 0 { return 1 }
        let day = (diff % max(21, cycleLengthDays)) + 1
        return day
    }

    /// Returns the active hormonal phase.
    func activePhase(on date: Date = Date()) -> CyclePhase {
        if let manual = manualOverridePhase {
            return manual
        }
        let day = currentDay(on: date)
        switch day {
        case 1...5:
            return .menstrual
        case 6...13:
            return .follicular
        case 14...16:
            return .ovulatory
        default:
            return .luteal
        }
    }

    /// Dynamic calorie adjustment.
    func calorieAdjustment(on date: Date = Date()) -> Int {
        guard isEnabled else { return 0 }
        return activePhase(on: date).caloricAdjustment
    }

    /// Dynamic protein adjustment.
    func proteinAdjustment(on date: Date = Date()) -> Int {
        guard isEnabled else { return 0 }
        return activePhase(on: date).proteinAdjustment
    }
}

/// Central manager for cycle-aware athletic fueling.
@MainActor
final class CycleManager: ObservableObject {
    static let shared = CycleManager()

    private static let storageKey = "safefuel.cycle_state"

    @Published var state: CycleState {
        didSet {
            save()
        }
    }

    @Published var isHealthKitSynced: Bool = false

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(CycleState.self, from: data) {
            self.state = decoded
        } else {
            self.state = CycleState()
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        }
    }

    /// Enable cycle tracking for female athletes.
    func enableForLadyAthlete() {
        state.isEnabled = true
    }

    /// Update the last period start date (either manually or from Apple Health).
    func updateLastPeriodStartDate(_ date: Date, syncedFromHealth: Bool = false) {
        state.lastPeriodStartDate = date
        state.manualOverridePhase = nil
        isHealthKitSynced = syncedFromHealth
    }

    /// Set a manual override phase.
    func setManualPhase(_ phase: CyclePhase?) {
        state.manualOverridePhase = phase
    }
}
