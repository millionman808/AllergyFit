import SwiftUI

/// The onboarding's own palette: a private members' club — deep racing green,
/// burnished brass, ivory linen, serif headlines. The rest of the app uses the
/// friendlier everyday `Theme`; the first impression is meant to feel
/// considered and premium, so it gets its own, quieter set.
///
/// Member names mirror `Theme.Colors` / `Theme.Fonts`, so onboarding views
/// swap namespaces without changing any call sites.
enum Club {
    enum Colors {
        static let background      = Color.dyn(0xF6F1E6, 0x0E1712)   // ivory linen / night green
        static let surface         = Color.dyn(0xFFFDF8, 0x15211A)
        static let surfaceRaised   = Color.dyn(0xEEE7D8, 0x1E2C24)
        static let parchmentBorder = Color.dyn(0xE2D8C5, 0x2A3A31)

        static let racingGreen     = Color.dyn(0x1F3D2E, 0x6E9E83)
        static let antiqueBrass    = Color.dyn(0xA8823F, 0xC9A961)
        static let waxCrimson      = Color.dyn(0x8A2C2C, 0xC56A5F)

        /// Primary action: green in light, brass in dark (green on night
        /// green would disappear).
        static let volt            = Color.dyn(0x1F3D2E, 0xC9A961)
        static let onVolt          = Color.dyn(0xF6F1E6, 0x0E1712)

        static let textPrimary     = Color.dyn(0x1A201C, 0xF1ECE1)
        static let textSecondary   = Color.dyn(0x56605A, 0xA9B0AA)
        static let textTertiary    = Color.dyn(0x8A918C, 0x6D7670)

        static let safe    = Theme.Colors.safe
        static let danger  = Theme.Colors.danger
        static let protein = Color.dyn(0x2E5A7A, 0x7FA7C9)
        static let carbs   = Color.dyn(0xA8823F, 0xC9A961)
        static let fat     = Color.dyn(0x6A3D6E, 0xB98BC0)
    }

    /// Serif display over a clean sans body — the classic premium pairing.
    enum Fonts {
        static func stat(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .serif) }
        static let title    = Font.system(.title2, design: .serif).weight(.semibold)
        static let headline = Font.system(.headline, design: .serif).weight(.semibold)
        static let body     = Font.system(.body, design: .default)
        static let caption  = Font.system(.caption, design: .default).weight(.medium)
        static func clubTag(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .semibold, design: .default) }
    }
}
