import SwiftUI
import UIKit

/// AllergyFit design tokens — "Bold & Athletic"
/// Adaptive light/dark palette; volt green signature accent.
enum Theme {

    // MARK: - Colors
    enum Colors {
        static let background = Color.dyn(0xF3F4EF, 0x0D0F12)
        static let surface = Color.dyn(0xFFFFFF, 0x16191F)
        static let surfaceRaised = Color.dyn(0xE6E9DF, 0x1E222B)

        /// Signature accent: electric volt green (deeper in light mode for contrast).
        static let volt = Color.dyn(0x7E9E22, 0xC8F04A)
        /// Text/icons placed ON a volt-filled control — always near-black.
        static let onVolt = Color(hex: 0x1C2306)

        static let safe = Color.dyn(0x0E9F6E, 0x34D399)
        static let caution = Color.dyn(0xB45309, 0xFBBF24)
        static let danger = Color.dyn(0xDC2626, 0xF87171)

        static let protein = Color.dyn(0x2563EB, 0x60A5FA)
        static let carbs = Color.dyn(0xDB2777, 0xF472B6)
        static let fat = Color.dyn(0xD97706, 0xFBBF24)

        static let textPrimary = Color.dyn(0x191D23, 0xF4F6F8)
        static let textSecondary = Color.dyn(0x555F6C, 0x9AA3AF)
        static let textTertiary = Color.dyn(0x98A0AB, 0x5C6470)
    }

    // MARK: - Typography
    enum Fonts {
        static func stat(_ size: CGFloat) -> Font {
            .system(size: size, weight: .heavy, design: .rounded)
        }
        static let title = Font.system(.title2, design: .rounded).weight(.bold)
        static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
        static let body = Font.system(.body, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded).weight(.medium)
    }

    // MARK: - Metrics
    enum Metrics {
        static let cornerRadius: CGFloat = 20
        static let cardPadding: CGFloat = 16
        static let screenPadding: CGFloat = 16
        static let spacing: CGFloat = 12
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// Dynamic color that adapts to light/dark appearance.
    static func dyn(_ light: UInt, _ dark: UInt) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }
}

// MARK: - Reusable card style
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Metrics.cardPadding)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}
