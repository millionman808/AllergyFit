import SwiftUI

/// How strongly a user reacts to a given allergen. Mirrors the Postgres
/// `severity_level` enum (mild < moderate < severe < anaphylaxis).
enum Sensitivity: String, CaseIterable, Codable, Comparable, Identifiable {
    case mild, moderate, severe, anaphylaxis

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mild: return "Mild"
        case .moderate: return "Moderate"
        case .severe: return "Severe"
        case .anaphylaxis: return "Anaphylaxis"
        }
    }

    /// Short form for compact chips.
    var short: String {
        switch self {
        case .mild: return "Mild"
        case .moderate: return "Mod"
        case .severe: return "Severe"
        case .anaphylaxis: return "Anaph"
        }
    }

    var color: Color {
        switch self {
        case .mild: return Theme.Colors.safe
        case .moderate: return Theme.Colors.caution
        case .severe: return Theme.Colors.danger
        case .anaphylaxis: return Theme.Colors.danger
        }
    }

    var icon: String {
        switch self {
        case .mild: return "circle.fill"
        case .moderate: return "exclamationmark.circle.fill"
        case .severe: return "exclamationmark.triangle.fill"
        case .anaphylaxis: return "cross.case.fill"
        }
    }

    /// One-line hint shown under the picker.
    var blurb: String {
        switch self {
        case .mild: return "Minor discomfort — small amounts may be OK."
        case .moderate: return "Clear reaction — best avoided."
        case .severe: return "Strong reaction — always avoid."
        case .anaphylaxis: return "Life-threatening — strict avoidance, carry epinephrine."
        }
    }

    private var rank: Int { Self.allCases.firstIndex(of: self)! }
    static func < (a: Sensitivity, b: Sensitivity) -> Bool { a.rank < b.rank }

    static func from(_ raw: String?) -> Sensitivity {
        Sensitivity(rawValue: (raw ?? "moderate").lowercased()) ?? .moderate
    }

    /// Best-effort mapping from a blood-test class/level string to a sensitivity.
    /// Conservative on purpose: IgE class reflects sensitization, not anaphylaxis
    /// risk, so we never auto-assign anaphylaxis — the user sets that themselves.
    static func fromLabLevel(_ level: String, positive: Bool) -> Sensitivity {
        let l = level.lowercased()
        if let n = firstInt(in: l) {
            switch n {
            case 0: return .mild
            case 1, 2: return .mild
            case 3, 4: return .moderate
            default: return .severe          // class 5, 6+
            }
        }
        if l.contains("very high") { return .severe }
        if l.contains("high") { return .severe }
        if l.contains("moderate") || l.contains("elevated") { return .moderate }
        if l.contains("low") { return .mild }
        return positive ? .moderate : .mild
    }

    private static func firstInt(in s: String) -> Int? {
        var digits = ""
        for ch in s {
            if ch.isNumber { digits.append(ch) }
            else if !digits.isEmpty { break }
        }
        return Int(digits)
    }
}
