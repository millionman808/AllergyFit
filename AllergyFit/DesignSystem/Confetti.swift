import SwiftUI

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
