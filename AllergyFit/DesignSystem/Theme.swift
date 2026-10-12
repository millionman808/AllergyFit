import SwiftUI
import UIKit

/// SafeFuel design tokens — "Finch Self-Care & Companion Care"
/// Soft warm cream, friendly pastel accents, chubby rounded typography, and pillowy cards.
enum Theme {

    // MARK: - Colors
    enum Colors {
        // Finch Cozy Canvas Tones
        static let background = Color(hex: 0xFAF8F5) // Warm cream linen (#FAF8F5)
        static let surface = Color.white // Cloud white
        static let surfaceRaised = Color(hex: 0xF4EFE6) // Soft almond oat
        static let parchmentBorder = Color(hex: 0xEAE4D7)

        // Signature Finch Pastel Palette
        static let finchMint = Color(hex: 0x4E7D3F) // Fresh avocado green
        static let finchPeach = Color(hex: 0xF08A5D) // Warm cozy peach
        static let finchButter = Color(hex: 0xF7B731) // Sunny buttercup yellow
        static let finchSky = Color(hex: 0x4EA5D9) // Morning sky blue
        static let finchLavender = Color(hex: 0x9D8DF1) // Soft mochi lavender
        static let finchRose = Color(hex: 0xEB6B80) // Sweet strawberry blush

        /// Primary accent: Finch Avocado Green
        static let volt = finchMint
        /// Text/icons on primary button
        static let onVolt = Color.white

        /// Status indicators
        static let safe = finchMint
        static let caution = Color(hex: 0xD97706)
        static let danger = Color(hex: 0xEB6B80)

        // Macro Nutrition Tones (Warm, edible pastels)
        static let protein = Color(hex: 0xF08A5D) // Salmon coral
        static let carbs = Color(hex: 0xF7B731) // Golden honey
        static let fat = Color(hex: 0x4EA5D9) // Soft sky
        static let caloriesRing = finchMint // Avocado energy ring

        // Typography Inks
        static let textPrimary = Color(hex: 0x2D312E)
        static let textSecondary = Color(hex: 0x6B7280)
        static let textTertiary = Color(hex: 0x9CA3AF)

        // Heritage compatibility aliases
        static let racingGreen = finchMint
        static let saddleLeather = finchPeach
        static let antiqueBrass = finchButter
        static let waxCrimson = finchRose
        static let carraraMarble = surfaceRaised
    }

    // MARK: - Typography (Chubby, Warm, Legible Rounded System Fonts)
    enum Fonts {
        /// Chubby rounded numbers for companion stats, calories, streaks
        static func stat(_ size: CGFloat) -> Font {
            .system(size: size, weight: .heavy, design: .rounded)
        }

        /// Cheerful rounded headlines
        static func display(_ size: CGFloat) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }

        static let title = Font.system(.title2, design: .rounded).weight(.bold)
        static let headline = Font.system(.headline, design: .rounded).weight(.bold)
        static let body = Font.system(.body, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded).weight(.semibold)

        static func clubTag(_ size: CGFloat = 11) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }
    }

    // MARK: - Metrics
    enum Metrics {
        static let cornerRadius: CGFloat = 28 // Pillowy Finch corners
        static let cardPadding: CGFloat = 18
        static let screenPadding: CGFloat = 18
        static let spacing: CGFloat = 14
        static let tabBarClearance: CGFloat = 115
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
        Color(uiColor: UIColor { trait in
            let hex = (trait.userInterfaceStyle == .dark) ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0,
                alpha: 1.0
            )
        })
    }
}

// MARK: - Pillowy Card Style
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Metrics.cardPadding)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.Colors.parchmentBorder.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 14, y: 5)
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

// MARK: - Bouncy Finch Press Microinteraction
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

extension View {
    func pressable() -> some View { buttonStyle(PressableButtonStyle()) }
}
