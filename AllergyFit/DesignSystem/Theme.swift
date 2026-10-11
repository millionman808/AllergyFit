import SwiftUI
import UIKit

/// SafeFuel design tokens — "Finch Self-Care & Companion Care"
/// Soft warm cream, friendly pastel accents, chubby rounded typography, and pillowy cards.
enum Theme {

    // MARK: - Colors
    enum Colors {
        // Finch Cozy Canvas Tones
        static let background = Color.dyn(0xFFFDF7, 0x18191D) // Warm cream linen
        static let surface = Color.dyn(0xFFFFFF, 0x22242B) // Cloud white
        static let surfaceRaised = Color.dyn(0xF7F3EA, 0x2C2F38) // Soft almond oat

        // Signature Finch Pastel Palette
        static let finchMint = Color.dyn(0x38A169, 0x48BB78) // Friendly leaf green
        static let finchPeach = Color.dyn(0xFF8A65, 0xFFA07A) // Warm cozy peach
        static let finchButter = Color.dyn(0xFBBF24, 0xFCD34D) // Sunny buttercup yellow
        static let finchSky = Color.dyn(0x38BDF8, 0x60A5FA) // Morning sky blue
        static let finchLavender = Color.dyn(0xA78BFA, 0xC4B5FD) // Soft mochi lavender
        static let finchRose = Color.dyn(0xFB7185, 0xFDA4AF) // Sweet strawberry blush
        static let parchmentBorder = Color.dyn(0xEFEAE0, 0x343844)

        /// Primary accent: Finch Meadow Mint
        static let volt = Color.dyn(0x38A169, 0x4ADE80)
        /// Text/icons on primary button
        static let onVolt = Color.white

        /// Status indicators
        static let safe = Color.dyn(0x16A34A, 0x4ADE80)
        static let caution = Color.dyn(0xD97706, 0xFBBF24)
        static let danger = Color.dyn(0xE11D48, 0xFB7185)

        // Macro Nutrition Tones (Warm, edible pastels)
        static let protein = Color.dyn(0xFF6F61, 0xFB7185) // Salmon coral
        static let carbs = Color.dyn(0xF59E0B, 0xFBBF24) // Golden honey
        static let fat = Color.dyn(0x84CC16, 0xA3E635) // Fresh pear olive
        static let caloriesRing = Color.dyn(0x38A169, 0x4ADE80) // Mint energy ring

        // Typography Inks
        static let textPrimary = Color.dyn(0x2D312E, 0xF3F4F6)
        static let textSecondary = Color.dyn(0x6B7280, 0x9CA3AF)
        static let textTertiary = Color.dyn(0x9CA3AF, 0x6B7280)

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
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
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
