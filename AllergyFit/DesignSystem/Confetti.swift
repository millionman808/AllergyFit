import SwiftUI

/// Finch-style confetti. Bump `trigger` to fire a burst; bursts overlap, so
/// checking off goals quickly keeps the party going. Draws with Canvas, so a
/// full burst stays cheap, and never takes touches.
struct ConfettiBurst: View {
    let trigger: Int
    /// A bigger, longer burst (every goal done, a hatch, an adventure).
    var big: Bool = false
    /// Where the confetti shoots from, as a fraction of the view.
    var origin: UnitPoint = UnitPoint(x: 0.5, y: 0.38)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bursts: [Burst] = []

    private struct Piece {
        let vx: CGFloat, vy: CGFloat
        let spin: Double, flutter: Double
        let size: CGSize
        let color: Color
        let round: Bool
    }

    private struct Burst: Identifiable {
        let id = UUID()
        let start = Date()
        let pieces: [Piece]
        let life: Double
    }

    private static let palette: [Color] = [
        Theme.Colors.finchMint, Theme.Colors.finchPeach, Theme.Colors.finchButter,
        Theme.Colors.finchSky, Theme.Colors.finchLavender, Theme.Colors.finchRose,
        Color(hex: 0xA3C76A)
    ]

    var body: some View {
        TimelineView(.animation(paused: bursts.isEmpty)) { timeline in
            Canvas { ctx, size in
                let now = timeline.date
                let ox = size.width * origin.x, oy = size.height * origin.y
                let gravity: CGFloat = 1500
                for burst in bursts {
                    let t = now.timeIntervalSince(burst.start)
                    guard t < burst.life else { continue }
                    let fade = max(0, min(1, (burst.life - t) / 0.6))
                    for p in burst.pieces {
                        // Air drag keeps pieces floating down instead of dropping like rocks.
                        let drag = CGFloat(1 - exp(-2.2 * t)) / 2.2
                        let x = ox + p.vx * drag
                        let y = oy + p.vy * drag + 0.5 * gravity * CGFloat(t * t) * 0.35
                        var piece = ctx
                        piece.opacity = fade
                        piece.translateBy(x: x, y: y)
                        piece.rotate(by: .radians(p.spin * t))
                        // Paper flips as it falls.
                        piece.scaleBy(x: CGFloat(cos(p.flutter * t)), y: 1)
                        let rect = CGRect(x: -p.size.width / 2, y: -p.size.height / 2,
                                          width: p.size.width, height: p.size.height)
                        let path = p.round ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 1.5)
                        piece.fill(path, with: .color(p.color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _ in fire() }
    }

    private func fire() {
        let count = reduceMotion ? 18 : (big ? 140 : 70)
        let speed: ClosedRange<CGFloat> = big ? 500...1150 : 380...850
        let pieces = (0..<count).map { _ -> Piece in
            let angle = Double.random(in: (-.pi * 0.92)...(-.pi * 0.08))   // upward fan
            let v = CGFloat.random(in: speed)
            let w = CGFloat.random(in: 6...11)
            return Piece(
                vx: CGFloat(cos(angle)) * v,
                vy: CGFloat(sin(angle)) * v,
                spin: Double.random(in: -9...9),
                flutter: Double.random(in: 5...14),
                size: CGSize(width: w, height: w * CGFloat.random(in: 0.45...0.9)),
                color: Self.palette.randomElement()!,
                round: Double.random(in: 0...1) < 0.25
            )
        }
        let life = big ? 3.4 : 2.6
        let burst = Burst(pieces: pieces, life: life)
        bursts.append(burst)
        DispatchQueue.main.asyncAfter(deadline: .now() + life + 0.1) {
            bursts.removeAll { $0.id == burst.id }
        }
    }
}

/// Full-screen confetti driven by Pip's store, mounted once above the tabs so
/// a goal checked anywhere in the app gets its celebration.
struct PipConfettiLayer: View {
    @ObservedObject private var pip = FuelFriendStore.shared

    var body: some View {
        ZStack {
            ConfettiBurst(trigger: pip.confettiSmall)
            ConfettiBurst(trigger: pip.confettiBig, big: true, origin: UnitPoint(x: 0.5, y: 0.3))
        }
        .ignoresSafeArea()
    }
}


// MARK: - Confetti (#25 Delight)
/// A short, lightweight confetti burst (Canvas particles, no dependencies).
/// Drop into a ZStack; it ignores touches and finishes on its own.
struct ConfettiView: View {
    private struct Particle {
        let x: CGFloat        // 0…1 horizontal start
        let delay: Double
        let speed: CGFloat    // fraction of height per second
        let size: CGFloat
        let sway: CGFloat
        let colorIndex: Int
        let spin: Double
    }

    private let colors: [Color] = [
        Theme.Colors.volt, Theme.Colors.protein, Theme.Colors.carbs,
        Theme.Colors.fat, Theme.Colors.safe,
    ]
    private let particles: [Particle] = (0..<70).map { i in
        Particle(
            x: .random(in: 0...1),
            delay: .random(in: 0...0.35),
            speed: .random(in: 0.55...1.0),
            size: .random(in: 5...9),
            sway: .random(in: 8...26),
            colorIndex: i,
            spin: .random(in: 2...6)
        )
    }
    private let start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            Canvas { ctx, size in
                for p in particles {
                    let time = t - p.delay
                    guard time > 0 else { continue }
                    let y = CGFloat(time) * p.speed * size.height - 20
                    guard y < size.height + 20 else { continue }
                    let x = p.x * size.width + CGFloat(sin(time * 3 + Double(p.colorIndex))) * p.sway
                    let rect = CGRect(x: -p.size / 2, y: -p.size * 0.8, width: p.size, height: p.size * 1.6)
                    var inner = ctx
                    inner.translateBy(x: x, y: y)
                    inner.rotate(by: .radians(time * p.spin))
                    inner.fill(Path(roundedRect: rect, cornerRadius: 1.5),
                               with: .color(colors[p.colorIndex % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
