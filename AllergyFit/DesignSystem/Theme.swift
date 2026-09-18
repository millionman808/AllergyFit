import SwiftUI
import UIKit

/// SafeFuel design tokens — "Old Money Athletic Club & Heritage Pavilion"
/// Sunlit alabaster, British racing green, saddle leather, and burnished brass.
enum Theme {

    // MARK: - Colors
    enum Colors {
        // Heritage Club Base Tones
        static let background = Color.dyn(0xFAF8F5, 0x0E1310) // Sunlit ecru linen in light, dark forest in dark
        static let surface = Color.dyn(0xFFFFFF, 0x161D18)
        static let surfaceRaised = Color.dyn(0xF0ECE1, 0x222C24)

        // Signature Heritage Tones
        static let racingGreen = Color(hex: 0x143424) // British Racing Green
        static let saddleLeather = Color(hex: 0x7E4924) // English Bridle Leather
        static let antiqueBrass = Color(hex: 0xC5A059) // Burnished Brass / Gold
        static let waxCrimson = Color(hex: 0x9B1D20) // Sealing Wax Red
        static let carraraMarble = Color(hex: 0xF3EFEA) // Polished Italian Marble
        static let parchmentBorder = Color.dyn(0xE8E2D7, 0x2B372E)

        /// Primary accent: British Racing Green in light mode, polished brass in dark mode.
        static let volt = Color.dyn(0x143424, 0xD4AF37)
        /// Text/icons placed on a primary filled button.
        static let onVolt = Color.dyn(0xFFFFFF, 0x0E1310)

        /// Status indicators
        static let safe = Color.dyn(0x1A6038, 0x3BE06B)
        static let caution = Color.dyn(0xB45309, 0xFBBF24)
        static let danger = Color.dyn(0x9B1D20, 0xF87171)

        // Macro Nutrition Ledger Colors
        static let protein = Color.dyn(0x1F4E79, 0x60A5FA)
        static let carbs = Color.dyn(0x9A3B5A, 0xF472B6)
        static let fat = Color.dyn(0xA8651E, 0xFBBF24)

        // Editorial Typography Inks
        static let textPrimary = Color.dyn(0x191D1A, 0xF5F6F4)
        static let textSecondary = Color.dyn(0x525B54, 0x9EA8A0)
        static let textTertiary = Color.dyn(0x8A948C, 0x5D685F)
    }

    // MARK: - Typography
    enum Fonts {
        /// Editorial Serif for major hero numbers and ledger amounts
        static func stat(_ size: CGFloat) -> Font {
            .system(size: size, weight: .semibold, design: .serif)
        }

        /// Bespoke Club Display headline (Baskerville / Serif)
        static func display(_ size: CGFloat) -> Font {
            if UIFont(name: "Baskerville-SemiBold", size: size) != nil {
                return Font.custom("Baskerville-SemiBold", size: size)
            }
            return Font.system(size: size, weight: .semibold, design: .serif)
        }

        /// Subheadings and section banners
        static let title = Font.system(.title2, design: .serif).weight(.semibold)
        static let headline = Font.system(.headline, design: .serif).weight(.medium)
        static let body = Font.system(.body, design: .default)
        static let caption = Font.system(.caption, design: .default).weight(.medium)

        /// High-end club ledger tag font (use with .tracking(2.0))
        static func clubTag(_ size: CGFloat = 11) -> Font {
            .system(size: size, weight: .bold, design: .default)
        }
    }

    // MARK: - Metrics
    enum Metrics {
        static let cornerRadius: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let screenPadding: CGFloat = 18
        static let spacing: CGFloat = 12
        static let tabBarClearance: CGFloat = 104
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
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.Colors.parchmentBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 3)
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

// MARK: - Press microinteraction (#23)
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    func pressable() -> some View { buttonStyle(PressableButtonStyle()) }
}
