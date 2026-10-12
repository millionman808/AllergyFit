import SwiftUI

/// The Finch-inspired palette: cozy warm cream background (#FAF8F5),
/// rounded typography, avocado greens (#4E7D3F), warm pit-brown (#6E4426), and pastel accents.
/// Member names mirror Theme.Colors / Theme.Fonts.
enum Club {
    enum Colors {
        static let background      = Color(hex: 0xFAF8F5)   // soft warm cream linen
        static let surface         = Color.white            // cloud white
        static let surfaceRaised   = Color(hex: 0xF4EFE6)   // soft almond oat
        static let parchmentBorder = Color(hex: 0xEAE4D7)

        static let avocadoGreen    = Color(hex: 0x4E7D3F)   // fresh avocado green
        static let pitBrown        = Color(hex: 0x6E4426)   // warm pit-brown
        static let pastelPeach     = Color(hex: 0xF08A5D)   // warm peach
        static let pastelButter    = Color(hex: 0xF7B731)   // sunny butter yellow
        static let pastelSky       = Color(hex: 0x4EA5D9)   // soft sky blue
        static let pastelLavender  = Color(hex: 0x9D8DF1)   // mochi lavender
        static let pastelRose      = Color(hex: 0xEB6B80)   // soft berry blush

        // Heritage compatibility aliases
        static let racingGreen     = avocadoGreen
        static let antiqueBrass    = pitBrown
        static let waxCrimson      = pastelPeach

        /// Primary action: Fresh Avocado Green
        static let volt            = avocadoGreen
        static let onVolt          = Color.white

        static let textPrimary     = Color(hex: 0x2A2E2B)
        static let textSecondary   = Color(hex: 0x6A726A)
        static let textTertiary    = Color(hex: 0x9CA49C)

        static let safe    = Color(hex: 0x4E7D3F)
        static let danger  = Color(hex: 0xEB6B80)
        static let protein = Color(hex: 0xF08A5D)
        static let carbs   = Color(hex: 0xF7B731)
        static let fat     = Color(hex: 0x4EA5D9)
    }

    /// Chubby, warm, rounded system fonts
    enum Fonts {
        static func stat(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
        static let title    = Font.system(.title2, design: .rounded).weight(.bold)
        static let headline = Font.system(.headline, design: .rounded).weight(.bold)
        static let body     = Font.system(.body, design: .rounded)
        static let caption  = Font.system(.caption, design: .rounded).weight(.semibold)
        static func clubTag(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    }
}
