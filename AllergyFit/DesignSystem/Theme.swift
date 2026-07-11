import SwiftUI
import UIKit

/// AllergyFit design tokens — "Bold & Athletic"
/// Adaptive light/dark palette; volt green signature accent.
enum Theme {

    // MARK: - Colors
    enum Colors {
        static let background = Color.dyn(0xF3F5EE, 0x0B0D10)
        static let surface = Color.dyn(0xFFFFFF, 0x15181E)
        static let surfaceRaised = Color.dyn(0xE7EADF, 0x222833)

        /// Signature accent: neon mint (bright on dark, deepened in light mode for contrast).
        static let volt = Color.dyn(0x0FA57E, 0x5FF2C2)
        /// Text/icons placed ON a mint-filled control — white on the deep light-mode
        /// mint, near-black on the bright dark-mode mint (best contrast in each).
        static let onVolt = Color.dyn(0xFFFFFF, 0x062018)

        /// Allergy-safe status: distinct grass green so it never reads as the mint accent.
        static let safe = Color.dyn(0x17913F, 0x3BE06B)
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
