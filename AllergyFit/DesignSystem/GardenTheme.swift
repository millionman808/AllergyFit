import SwiftUI

/// Design System for the Living Outdoor Garden Companion Stage.
/// Provides environmental palette tokens, atmospheric outdoor backdrops,
/// and the progressive 5-stage living botanical plant growth engine.
enum GardenTheme {

    // MARK: - Atmospheric Colors
    enum Colors {
        // Sky & Atmosphere
        static let skyTop = Color(hex: 0xBBE3F8)          // Crisp morning blue
        static let skyBottom = Color(hex: 0xEFF8FE)       // Soft horizon haze
        static let sunCore = Color(hex: 0xFEE479)         // Warm buttercup sun
        static let sunGlow = Color(hex: 0xFEF08A).opacity(0.55) // Ambient sunshine corona
        static let cloudPuff = Color.white.opacity(0.85)

        // Rolling Meadow Hills
        static let distantHill = Color(hex: 0x93DC9A)     // Distant rolling green
        static let midHill = Color(hex: 0x6FC877)         // Midground meadow ridge
        static let lawnForeground = Color(hex: 0x569C3A)  // Lush foreground turf
        static let lawnHighlight = Color(hex: 0x73B84E)   // Sun-kissed grass crest
        static let soilRich = Color(hex: 0x513824)        // Moist organic potting soil

        // Botanical Tones
        static let sproutLime = Color(hex: 0x8BE328)      // Tender baby leaf
        static let leafEmerald = Color(hex: 0x3E7B2F)     // Healthy avocado foliage
        static let leafForest = Color(hex: 0x2C5E20)      // Deep inner canopy
        static let stemHealthy = Color(hex: 0x598E3A)     // Sturdy vascular stem
        static let blossomGold = Color(hex: 0xFFDE59)     // Blooming chamomile flower
        static let avocadoFruit = Color(hex: 0x486B26)    // Ripe baby avocado
        static let stonePicnic = Color(hex: 0xE8DFC9)     // Stepping stone / wood slice
    }
}

// MARK: - Outdoor Garden Backdrop
/// Renders an idyllic, peaceful outdoor sanctuary with soft rolling hills,
/// warm glowing sun, animated drifting clouds, and foreground turf with cheerful wildflowers.
struct OutdoorGardenBackdrop: View {
    @State private var cloudOffsetA: CGFloat = -18
    @State private var cloudOffsetB: CGFloat = 16
    @State private var sunPulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Sky Gradient
            LinearGradient(
                colors: [GardenTheme.Colors.skyTop, GardenTheme.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            // Radiant Sunshine Orb & Rays
            GeometryReader { geo in
                ZStack {
                    // Soft Ambient Corona
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [GardenTheme.Colors.sunGlow, Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 75
                            )
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(sunPulse)

                    // Core Sun
                    Circle()
                        .fill(GardenTheme.Colors.sunCore)
                        .frame(width: 44, height: 44)
                        .shadow(color: GardenTheme.Colors.sunCore.opacity(0.6), radius: 10)
                }
                .position(x: geo.size.width * 0.82, y: geo.size.height * 0.22)
            }

            // Drifting Fluffy Clouds
            GeometryReader { geo in
                // Cloud 1
                cloudShape(width: 74, height: 26)
                    .position(x: geo.size.width * 0.26 + cloudOffsetA, y: geo.size.height * 0.24)

                // Cloud 2
                cloudShape(width: 60, height: 22)
                    .position(x: geo.size.width * 0.64 + cloudOffsetB, y: geo.size.height * 0.16)
            }

            // Layered Rolling Meadow Hills
            VStack {
                Spacer()

                ZStack(alignment: .bottom) {
                    // Distant Hill 1
                    Ellipse()
                        .fill(GardenTheme.Colors.distantHill)
                        .frame(width: 320, height: 110)
                        .offset(x: -80, y: 35)

                    // Distant Hill 2
                    Ellipse()
                        .fill(GardenTheme.Colors.midHill)
                        .frame(width: 340, height: 115)
                        .offset(x: 90, y: 30)

                    // Foreground Lush Grassy Knoll
                    UnevenRoundedRectangle(
                        topLeadingRadius: 60,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 60,
                        style: .continuous
                    )
                    .fill(
                        LinearGradient(
                            colors: [GardenTheme.Colors.lawnHighlight, GardenTheme.Colors.lawnForeground],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 70)
                    .overlay(alignment: .top) {
                        wildflowersRow
                            .offset(y: 4)
                    }
                }
            }
        }
        .clipped()
        .onAppear {
            withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true)) {
                cloudOffsetA = 18
                cloudOffsetB = -16
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                sunPulse = 1.08
            }
        }
    }

    private func cloudShape(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: -width * 0.22) {
            Circle()
                .fill(GardenTheme.Colors.cloudPuff)
                .frame(width: height * 0.9, height: height * 0.9)
            Circle()
                .fill(GardenTheme.Colors.cloudPuff)
                .frame(width: height * 1.25, height: height * 1.25)
                .offset(y: -height * 0.15)
            Circle()
                .fill(GardenTheme.Colors.cloudPuff)
                .frame(width: height * 0.85, height: height * 0.85)
        }
        .frame(width: width, height: height)
        .shadow(color: Color.white.opacity(0.3), radius: 4)
    }

    // Cheerful tiny meadow wildflowers on the turf
    private var wildflowersRow: some View {
        HStack(spacing: 24) {
            flowerDot(color: Color(hex: 0xFDE047), size: 5) // Buttercup
            Spacer()
            flowerDot(color: Color.white, size: 6)           // Chamomile
            Spacer()
            flowerDot(color: Color(hex: 0xF472B6), size: 5) // Sweet pink clover
            Spacer()
            flowerDot(color: Color(hex: 0xFDE047), size: 4)
            Spacer()
            flowerDot(color: Color.white, size: 5)
        }
        .padding(.horizontal, 28)
    }

    private func flowerDot(color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.4), radius: 2)
    }
}

// MARK: - Living Growing Plant View
/// Progressive botanical plant engine with 5 distinct growth stages.
/// The plant visibly grows from the equipped pot, swaying gently in the outdoor breeze.
struct GrowingPlantView: View {
    let level: Int
    let potAsset: String
    var isHydrating: Bool = false

    @State private var breezeAngle: Double = -2.5
    @State private var waterDropPulse: CGFloat = 0.0

    // Plant stage: 1..5
    var stage: Int {
        switch level {
        case 1: return 1
        case 2...3: return 2
        case 4...6: return 3
        case 7...10: return 4
        default: return 5
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Ground Contact Shadow for the Pot
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: 58, height: 14)
                .blur(radius: 2)
                .offset(y: 4)

            // The Plant Pot
            Image(potAsset)
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .shadow(color: Color.black.opacity(0.12), radius: 4, y: 3)

            // Botanical Growth Layer emerging from Pot Soil
            plantFoliage
                .offset(y: -44)
                .rotationEffect(.degrees(breezeAngle), anchor: .bottom)

            // Water Droplet Animation when Hydrating
            if isHydrating {
                VStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: 0x38BDF8))
                        .offset(y: waterDropPulse)
                        .opacity(waterDropPulse == 0 ? 0 : 0.9)
                }
                .offset(y: -70)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                breezeAngle = 2.5
            }
        }
        .onChange(of: isHydrating) { hydrating in
            if hydrating {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    waterDropPulse = 24
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    waterDropPulse = 0
                }
            }
        }
    }

    // MARK: - Foliage Growth by Stage

    @ViewBuilder
    private var plantFoliage: some View {
        switch stage {
        case 1:
            // Stage 1: Little Sprout (Cracked pit + tender bright lime sprout)
            sproutStageView
        case 2:
            // Stage 2: Growing Roots (Sturdy young stem + twin healthy leaves)
            youngSeedlingView
        case 3:
            // Stage 3: Little Garden (Branched bush with vibrant leaves & flower buds)
            gardenBushView
        case 4:
            // Stage 4: Flourishing (Miniature avocado tree + young avocado fruit)
            flourishingBonsaiView
        default:
            // Stage 5: Thriving Together (Lush magnificent fruiting tree + blossoms)
            thrivingCanopyView
        }
    }

    // STAGE 1: Baby Sprout
    private var sproutStageView: some View {
        ZStack(alignment: .bottom) {
            // Little cracked seed sitting in soil
            Circle()
                .fill(Color(hex: 0x6E4426))
                .frame(width: 18, height: 18)
                .overlay(
                    Capsule()
                        .fill(GardenTheme.Colors.sproutLime)
                        .frame(width: 4, height: 12)
                        .offset(y: -2)
                )

            // First green sprout leaf with dewdrop
            Image(systemName: "leaf.fill")
                .font(.system(size: 20))
                .foregroundStyle(GardenTheme.Colors.sproutLime)
                .rotationEffect(.degrees(18))
                .offset(x: 4, y: -14)

            // Tiny dewdrop
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 4, height: 4)
                .offset(x: 10, y: -20)
        }
    }

    // STAGE 2: Young Seedling
    private var youngSeedlingView: some View {
        ZStack(alignment: .bottom) {
            // Stem
            RoundedRectangle(cornerRadius: 2)
                .fill(GardenTheme.Colors.stemHealthy)
                .frame(width: 4, height: 26)

            // Left Leaf
            Image(systemName: "leaf.fill")
                .font(.system(size: 22))
                .foregroundStyle(GardenTheme.Colors.leafEmerald)
                .rotationEffect(.degrees(-38))
                .offset(x: -12, y: -16)

            // Right Leaf
            Image(systemName: "leaf.fill")
                .font(.system(size: 24))
                .foregroundStyle(GardenTheme.Colors.sproutLime)
                .rotationEffect(.degrees(38))
                .offset(x: 12, y: -20)
        }
    }

    // STAGE 3: Little Garden Bush
    private var gardenBushView: some View {
        ZStack(alignment: .bottom) {
            // Main Stem
            RoundedRectangle(cornerRadius: 3)
                .fill(GardenTheme.Colors.stemHealthy)
                .frame(width: 5, height: 34)

            // Side Branches
            Image(systemName: "leaf.fill")
                .font(.system(size: 22))
                .foregroundStyle(GardenTheme.Colors.leafForest)
                .rotationEffect(.degrees(-50))
                .offset(x: -16, y: -14)

            Image(systemName: "leaf.fill")
                .font(.system(size: 24))
                .foregroundStyle(GardenTheme.Colors.leafEmerald)
                .rotationEffect(.degrees(50))
                .offset(x: 16, y: -18)

            // Center Canopy Leaves
            Image(systemName: "leaf.fill")
                .font(.system(size: 28))
                .foregroundStyle(GardenTheme.Colors.sproutLime)
                .rotationEffect(.degrees(-10))
                .offset(x: -5, y: -28)

            Image(systemName: "leaf.fill")
                .font(.system(size: 26))
                .foregroundStyle(GardenTheme.Colors.leafEmerald)
                .rotationEffect(.degrees(20))
                .offset(x: 8, y: -30)

            // Blooming Golden Flower Bud
            Circle()
                .fill(GardenTheme.Colors.blossomGold)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                .shadow(color: GardenTheme.Colors.blossomGold.opacity(0.8), radius: 3)
                .offset(x: 0, y: -38)
        }
    }

    // STAGE 4: Flourishing Miniature Tree
    private var flourishingBonsaiView: some View {
        ZStack(alignment: .bottom) {
            // Sturdy Trunk
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: 0x5C3E21))
                .frame(width: 7, height: 40)

            // Rich Leafy Canopy
            Group {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(GardenTheme.Colors.leafForest)
                    .rotationEffect(.degrees(-60))
                    .offset(x: -18, y: -22)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(GardenTheme.Colors.leafEmerald)
                    .rotationEffect(.degrees(55))
                    .offset(x: 18, y: -24)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(GardenTheme.Colors.leafEmerald)
                    .rotationEffect(.degrees(-20))
                    .offset(x: -10, y: -36)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(GardenTheme.Colors.sproutLime)
                    .rotationEffect(.degrees(25))
                    .offset(x: 10, y: -38)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(GardenTheme.Colors.sproutLime)
                    .offset(x: 0, y: -44)
            }

            // Developing Baby Avocado Hanging
            HStack(spacing: 2) {
                Capsule()
                    .fill(GardenTheme.Colors.avocadoFruit)
                    .frame(width: 9, height: 13)
                    .shadow(color: Color.black.opacity(0.18), radius: 2, y: 1)
            }
            .offset(x: 14, y: -14)

            // Chamomile Blossoms
            blossomPair
                .offset(y: -42)
        }
    }

    // STAGE 5: Thriving Mature Tree
    private var thrivingCanopyView: some View {
        ZStack(alignment: .bottom) {
            // Majestic Wooden Trunk
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(hex: 0x51351A))
                .frame(width: 8, height: 46)

            // Vitality Aura Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [GardenTheme.Colors.blossomGold.opacity(0.35), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 45
                    )
                )
                .frame(width: 90, height: 90)
                .offset(y: -36)

            // Grand Canopy
            Group {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(GardenTheme.Colors.leafForest)
                    .rotationEffect(.degrees(-65))
                    .offset(x: -24, y: -26)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(GardenTheme.Colors.leafEmerald)
                    .rotationEffect(.degrees(65))
                    .offset(x: 24, y: -28)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(GardenTheme.Colors.leafEmerald)
                    .rotationEffect(.degrees(-25))
                    .offset(x: -12, y: -42)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(GardenTheme.Colors.sproutLime)
                    .rotationEffect(.degrees(25))
                    .offset(x: 12, y: -44)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(GardenTheme.Colors.sproutLime)
                    .offset(x: 0, y: -52)
            }

            // Ripe Avocado Fruits
            HStack(spacing: 24) {
                Capsule()
                    .fill(GardenTheme.Colors.avocadoFruit)
                    .frame(width: 10, height: 15)
                    .overlay(Circle().fill(Color(hex: 0x6E4426)).frame(width: 4, height: 4).offset(y: 1))
                    .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)

                Capsule()
                    .fill(GardenTheme.Colors.avocadoFruit)
                    .frame(width: 11, height: 16)
                    .overlay(Circle().fill(Color(hex: 0x6E4426)).frame(width: 4, height: 4).offset(y: 1))
                    .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
            }
            .offset(y: -18)

            // Golden Blooming Blossoms
            HStack(spacing: 20) {
                blossomDot
                blossomDot
            }
            .offset(y: -48)
        }
    }

    private var blossomPair: some View {
        HStack(spacing: 16) {
            blossomDot
            blossomDot
        }
    }

    private var blossomDot: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
            Circle()
                .fill(GardenTheme.Colors.blossomGold)
                .frame(width: 4, height: 4)
        }
        .shadow(color: GardenTheme.Colors.blossomGold.opacity(0.8), radius: 2)
    }
}

// MARK: - Garden Stepping Stone Decor Base
/// Grounds decor items (e.g. teacup, water cup) onto a natural garden stepping stone / wood slice
/// so items feel physically placed in the outdoor environment.
struct GardenSteppingStoneDecor: View {
    let decorId: String

    var body: some View {
        if let item = FuelFriendStore.allDecor.first(where: { $0.id == decorId }) {
            ZStack(alignment: .bottom) {
                // Ground Contact Shadow
                Ellipse()
                    .fill(Color.black.opacity(0.16))
                    .frame(width: 44, height: 12)
                    .blur(radius: 2)
                    .offset(y: 4)

                // Natural River Stepping Stone Base
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [GardenTheme.Colors.stonePicnic, Color(hex: 0xD8CFBA)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 42, height: 14)
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)

                // The Equipped Decor Item
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(hex: item.tintHex))
                    .shadow(color: Color.black.opacity(0.14), radius: 3, y: 2)
                    .offset(y: -10)
            }
            .frame(width: 48, height: 48)
        }
    }
}
