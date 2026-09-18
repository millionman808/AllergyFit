import SwiftUI

// Hero pieces for the pre-account funnel. The layout language is borrowed from
// the best consumer onboarding out there: one big headline with a single
// highlighted phrase, one composed visual per slide, colour used sparingly and
// on purpose. Everything here is drawn with SwiftUI primitives — no assets —
// so it renders identically on every device and in both appearances.

// MARK: - Headline with one highlighted phrase

/// "Your ~nutrition coach~ is here to help." The highlight is the payoff of
/// the sentence; there should only ever be one per slide.
struct HighlightHeadline: View {
    let text: String
    let highlight: String
    var size: CGFloat = 32

    var body: some View {
        styled
            .font(Theme.Fonts.stat(size))
            .foregroundStyle(Theme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(2)
    }

    private var styled: Text {
        guard let r = text.range(of: highlight) else { return Text(text) }
        let before = String(text[..<r.lowerBound])
        let after = String(text[r.upperBound...])
        return Text(before)
            + Text(highlight)
                .foregroundColor(Theme.Colors.volt)
                .underline(true, color: Theme.Colors.antiqueBrass)
            + Text(after)
    }
}

// MARK: - Palette for tiles and chips

/// The club's colours: racing green, brass, sealing-wax red, slate, plum,
/// sand. Six, so a list of triggers stays legible but never looks like a
/// rainbow.
enum HeroTint: CaseIterable {
    case mint, coral, amber, sky, lilac, sand
    var color: Color {
        switch self {
        case .mint:  return Theme.Colors.racingGreen
        case .coral: return Theme.Colors.waxCrimson
        case .amber: return Theme.Colors.antiqueBrass
        case .sky:   return Color.dyn(0x2E5A7A, 0x7FA7C9)   // slate
        case .lilac: return Color.dyn(0x6A3D6E, 0xB98BC0)   // plum
        case .sand:  return Color.dyn(0xB08A5A, 0xD9BE95)   // sand
        }
    }
    /// White text reads on every heritage tint except sand and brass.
    var wantsDarkText: Bool { self == .amber || self == .sand }
    static func at(_ i: Int) -> HeroTint { allCases[i % allCases.count] }
}

// MARK: - Food tile grid (welcome)

/// A 3×3 mosaic of safe-looking food on softly tinted tiles that pop in one
/// after another. Says "this is about food, and it's not scary" before a
/// single word is read.
struct FoodTileGrid: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    private let foods = ["🥗", "🍣", "🥑", "🍓", "🍗", "🥕", "🫐", "🍠", "🥥"]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(Array(foods.enumerated()), id: \.offset) { i, food in
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(HeroTint.at(i).color.opacity(0.14))
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(HeroTint.at(i).color.opacity(0.35), lineWidth: 1)
                    Text(food).font(.system(size: 44))
                }
                .aspectRatio(1, contentMode: .fit)
                .scaleEffect(shown ? 1 : 0.6)
                .opacity(shown ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7).delay(0.05 * Double(i)), value: shown)
            }
        }
        .onAppear { shown = true }
    }
}

// MARK: - Floating card on a tilted swatch (trust, goals)

/// A rounded colour swatch rotated a few degrees, with a crisp card floating
/// over it and a large emoji peeking out from behind — the "photo on torn
/// paper" effect, without the photo.
struct SwatchCard: View {
    let tint: HeroTint
    let emoji: String
    let title: String
    var subtitle: String? = nil
    var badge: String? = nil
    var selected: Bool = false
    var tilt: Double = -6

    var body: some View {
        ZStack {
            // The colour swatch: a slightly smaller, tilted slab behind the card.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [tint.color.opacity(selected ? 0.85 : 0.62), tint.color.opacity(selected ? 0.55 : 0.36)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .rotationEffect(.degrees(tilt))
                .padding(.horizontal, 30)
                .padding(.vertical, 14)
            VStack(spacing: 6) {
                if let badge {
                    Text(badge.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(tint.color)
                        .tracking(1)
                }
                Text(title)
                    .font(Theme.Fonts.stat(20))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(selected ? tint.color : Theme.Colors.parchmentBorder, lineWidth: selected ? 1.5 : 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 18, y: 10)
            .padding(.horizontal, 52)
            // The food sits on the corner like a sticker, half over the card edge.
            Text(emoji)
                .font(.system(size: 58))
                .rotationEffect(.degrees(12))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
                .offset(x: 128, y: -62)
        }
        .frame(height: 190)
    }
}

// MARK: - Stacked, slightly rotated cards (insights)

struct StackedInsightCards: View {
    struct Item { let tag: String; let icon: String; let tint: HeroTint; let text: String }
    let items: [Item]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                VStack(alignment: .leading, spacing: 10) {
                    Label(item.tag, systemImage: item.icon)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(item.tint.color)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(item.tint.color.opacity(0.14), in: Capsule())
                    Text(item.text)
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.Colors.parchmentBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
                .rotationEffect(.degrees(shown ? Double(i - 1) * 2.0 : 0))
                .offset(x: CGFloat(i - 1) * 8, y: CGFloat(i) * 104)
                .opacity(shown ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.78).delay(0.12 * Double(i)), value: shown)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 110 + CGFloat(max(items.count - 1, 0)) * 104 + 12, alignment: .top)
        .onAppear { shown = true }
    }
}

// MARK: - App preview card (coach)

/// A miniature of the Today screen built from the real ring components, so
/// the preview is honest about what the app looks like.
struct TodayPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today").font(Theme.Fonts.stat(22)).foregroundStyle(Theme.Colors.textPrimary)
                    Text("Eat with confidence").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle().fill(Theme.Colors.volt).frame(width: 34, height: 34)
                    Image(systemName: "sparkles").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.Colors.onVolt)
                }
            }
            HStack(spacing: 14) {
                ring(0.53, Theme.Colors.volt, size: 92, width: 9) {
                    VStack(spacing: 0) {
                        Text("1,520").font(Theme.Fonts.stat(20)).foregroundStyle(Theme.Colors.textPrimary)
                        Text("cal left").font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    macro("Protein", "78 of 180g", Theme.Colors.protein, 0.43)
                    macro("Carbs", "166 of 320g", Theme.Colors.carbs, 0.52)
                    macro("Fat", "37 of 84g", Theme.Colors.fat, 0.44)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill").foregroundStyle(Theme.Colors.safe)
                Text("Oat & blueberry bowl · safe for you")
                    .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text("420").font(Theme.Fonts.caption.weight(.bold)).foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(12)
            .background(Theme.Colors.surfaceRaised.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(18)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.Colors.parchmentBorder, lineWidth: 1))
        .shadow(color: Theme.Colors.racingGreen.opacity(0.14), radius: 30, y: 14)
    }

    private func ring<C: View>(_ p: Double, _ c: Color, size: CGFloat, width: CGFloat, @ViewBuilder _ center: () -> C) -> some View {
        ZStack {
            Circle().stroke(c.opacity(0.18), lineWidth: width)
            Circle().trim(from: 0, to: p).stroke(c, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center()
        }
        .frame(width: size, height: size)
    }

    private func macro(_ name: String, _ v: String, _ c: Color, _ p: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text(v).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(Theme.Colors.textTertiary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(c.opacity(0.18))
                    Capsule().fill(c).frame(width: g.size.width * p)
                }
            }
            .frame(height: 5)
        }
    }
}

// MARK: - Colour chips (triggers)

/// Multi-select chips where each selected chip takes its own hue — so a
/// person's list of triggers reads as *theirs*, not as a row of identical
/// toggles.
struct ColorChips: View {
    let items: [String]
    @Binding var selected: Set<String>
    var onAddCustom: (() -> Void)? = nil

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.element) { i, item in
                let on = selected.contains(item)
                let tint = HeroTint.at(i)
                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.68)) {
                        if on { selected.remove(item) } else { selected.insert(item) }
                    }
                } label: {
                    Text(item)
                        .font(Theme.Fonts.body.weight(on ? .semibold : .regular))
                        .lineLimit(1)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(on ? tint.color : Theme.Colors.surface, in: Capsule())
                        .foregroundStyle(on ? (tint.wantsDarkText ? Color(hex: 0x1A1A14) : Color.white) : Theme.Colors.textSecondary)
                        .overlay(Capsule().strokeBorder(on ? .clear : Theme.Colors.parchmentBorder, lineWidth: 1))
                        .scaleEffect(on ? 1.04 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            if let onAddCustom {
                Button { Haptics.tap(); onAddCustom() } label: {
                    Label("Something else", systemImage: "plus")
                        .font(Theme.Fonts.body)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .foregroundStyle(Theme.Colors.volt)
                        .background(Theme.Colors.volt.opacity(0.10), in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.Colors.volt.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Wrapping horizontal layout — chips flow left to right and wrap like text.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}

// MARK: - "Got it" summary (plan reveal)

/// The assembled profile: every choice from the funnel as a coloured chip on
/// one card, so people see the app *heard* them before they're asked to sign up.
struct GotItCard: View {
    let name: String
    let chips: [(String, HeroTint)]

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.Colors.volt.opacity(0.14)).frame(width: 64, height: 64)
                Image(systemName: "person.fill").font(.system(size: 28)).foregroundStyle(Theme.Colors.volt)
            }
            Text(name).font(Theme.Fonts.stat(20)).foregroundStyle(Theme.Colors.textPrimary)
            FlowLayout(spacing: 6) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, c in
                    Text(c.0)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(c.1.color.opacity(0.22), in: Capsule())
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.Colors.parchmentBorder, lineWidth: 1))
    }
}


// MARK: - Club crest (welcome)

/// Racing-green medallion with a brass ring — the club's mark.
struct ClubCrest: View {
    var size: CGFloat = 64
    var body: some View {
        ZStack {
            Circle().fill(Theme.Colors.racingGreen)
            Circle().strokeBorder(Theme.Colors.antiqueBrass, lineWidth: size * 0.05)
            Image(systemName: "laurel.leading")
                .font(.system(size: size * 0.36, weight: .regular))
                .foregroundStyle(Theme.Colors.antiqueBrass)
                .offset(x: -size * 0.2)
            Image(systemName: "laurel.trailing")
                .font(.system(size: size * 0.36, weight: .regular))
                .foregroundStyle(Theme.Colors.antiqueBrass)
                .offset(x: size * 0.2)
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: size * 0.3, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.Colors.racingGreen.opacity(0.25), radius: 10, y: 6)
    }
}

// MARK: - Locker card (gender)

/// The member's kit, photographed flat on marble. The photo carries the
/// meaning; the copy underneath stays plain.
struct LockerCard: View {
    let image: String
    let tag: String
    let title: String
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tag.uppercased())
                    .font(Theme.Fonts.clubTag(10)).tracking(1.8)
                    .foregroundStyle(Theme.Colors.antiqueBrass)
                Spacer()
                ZStack {
                    Circle().fill(isSelected ? Theme.Colors.waxCrimson : Color.clear)
                        .overlay(Circle().strokeBorder(isSelected ? .clear : Theme.Colors.parchmentBorder, lineWidth: 1.5))
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    }
                }
            }
            Image(image)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Theme.Colors.antiqueBrass : Color.clear, lineWidth: 1.5))
            Text(title)
                .font(Theme.Fonts.stat(22))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(14)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(isSelected ? Theme.Colors.racingGreen : Theme.Colors.parchmentBorder, lineWidth: isSelected ? 1.5 : 1))
        .shadow(color: .black.opacity(isSelected ? 0.10 : 0.05), radius: 12, y: 6)
    }
}
