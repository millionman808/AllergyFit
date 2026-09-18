import SwiftUI

/// Motion & spatial kit for the "Member's Kitchen" onboarding funnel.
/// Features directional kinetic sliding, persistent marble prep counter surfaces,
/// and tactile sealing wax stamps.

struct RevealIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (shown ? 0 : 18))
            .onAppear {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.85).delay(delay)) {
                        shown = true
                    }
                }
            }
    }
}

struct ScatterIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    @State private var shown = false

    private var dx: CGFloat { index.isMultiple(of: 2) ? -40 : 40 }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(x: reduceMotion ? 0 : (shown ? 0 : dx),
                    y: reduceMotion ? 0 : (shown ? 0 : 20))
            .onAppear {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)
                        .delay(0.06 + Double(index) * 0.06)) {
                        shown = true
                    }
                }
            }
    }
}

extension View {
    func revealIn(_ order: Int) -> some View {
        modifier(RevealIn(delay: 0.04 + Double(order) * 0.06))
    }
    func scatterIn(_ index: Int) -> some View {
        modifier(ScatterIn(index: index))
    }
}

// MARK: - Transitions
extension AnyTransition {
    static var onboardingStep: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    /// Kinetic horizontal slide mimicking sliding along the marble prep bench.
    static func directionalSlide(forward: Bool) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.97)),
            removal: .move(edge: forward ? .leading : .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 1.01))
        )
    }
}

// MARK: - Physical Kitchen Components

/// Persistent Carrara Marble & Brass Prep Counter surface
struct PrepCounterSurface: View {
    var body: some View {
        VStack(spacing: 0) {
            // Polished brass bullnose trim rail
            LinearGradient(
                colors: [
                    Color(hex: 0xD4AF37),
                    Color(hex: 0xF3E5AB),
                    Color(hex: 0xC5A059),
                    Color(hex: 0x8E6D24)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 3)
            .shadow(color: Color.black.opacity(0.15), radius: 2, y: 1)

            // Warm Carrara Italian marble slab with subtle edge shading
            ZStack(alignment: .top) {
                Color(hex: 0xF5F2EB)
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.04), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Hand-carved marble shadow edge
                Rectangle()
                    .fill(Color(hex: 0xE2DDD3))
                    .frame(height: 1)
            }
            .frame(height: 36)
        }
    }
}

/// Tactile Club Wax Seal Stamp
struct WaxSealStamp: View {
    var text: String = "SFAC"
    var size: CGFloat = 34
    var color: Color = Color(hex: 0x9B1D20) // Sealing wax red

    var body: some View {
        ZStack {
            // Irregular organic wax outer shape
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.95), color],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: size
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.28), radius: 3, y: 2)

            // Debossed inner ring
            Circle()
                .strokeBorder(Color.black.opacity(0.2), lineWidth: 1)
                .frame(width: size * 0.72, height: size * 0.72)

            // Monogram
            Text(text)
                .font(.system(size: size * 0.32, weight: .bold, design: .serif))
                .foregroundStyle(Color(hex: 0xFFE8D6))
                .shadow(color: Color.black.opacity(0.4), radius: 0.5, y: 0.5)
        }
    }
}
