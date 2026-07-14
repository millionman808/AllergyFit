import UIKit

/// Small, consistent haptic vocabulary used across the app (#8 Feedback, #25 Delight).
/// No-ops on the simulator; safe to call from anywhere on the main actor.
@MainActor
enum Haptics {
    /// A light tap — toggles, increments, minor confirmations.
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// A satisfying success — meal logged, recipe saved, plan added, onboarding done.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// A gentle warning — something went wrong or an action was blocked.
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
