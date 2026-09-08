import SwiftUI

/// Motion kit for the onboarding funnel.
///
/// Two effects, used sparingly so they read as polish rather than noise:
/// `revealIn` staggers content upward as a step appears, and `scatterIn`
/// fans cards in from alternating sides for celebratory moments.
/// Both collapse to a plain fade when Reduce Motion is on.

struct RevealIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (shown ? 0 : 22))
            .scaleEffect(reduceMotion ? 1 : (shown ? 1 : 0.98), anchor: .top)
            .onAppear {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(delay)) {
                        shown = true
                    }
                }
            }
    }
}

/// Fans an element in from the side — alternating direction by index so a row
/// of cards assembles itself instead of appearing all at once.
struct ScatterIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    @State private var shown = false

    private var dx: CGFloat { index.isMultiple(of: 2) ? -54 : 54 }
    private var rot: Double { index.isMultiple(of: 2) ? -7 : 7 }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(x: reduceMotion ? 0 : (shown ? 0 : dx),
                    y: reduceMotion ? 0 : (shown ? 0 : 26))
            .rotationEffect(.degrees(reduceMotion ? 0 : (shown ? 0 : rot)))
            .scaleEffect(reduceMotion ? 1 : (shown ? 1 : 0.9))
            .onAppear {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.68)
                        .delay(0.08 + Double(index) * 0.07)) {
                        shown = true
                    }
                }
            }
    }
}

extension View {
    /// Staggered upward reveal. `order` is the element's position in the step.
    func revealIn(_ order: Int) -> some View {
        modifier(RevealIn(delay: 0.04 + Double(order) * 0.07))
    }
    /// Springy fan-in from alternating sides, for payoff moments.
    func scatterIn(_ index: Int) -> some View {
        modifier(ScatterIn(index: index))
    }
}

extension AnyTransition {
    /// Step-to-step transition: outgoing content drifts and tilts away while
    /// the incoming step slides in from the opposite edge.
    static var onboardingStep: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .modifier(
                active: DriftAway(active: true),
                identity: DriftAway(active: false)))
    }
}

struct DriftAway: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content
            .opacity(active ? 0 : 1)
            .offset(x: active ? -70 : 0)
            .scaleEffect(active ? 0.94 : 1)
            .rotationEffect(.degrees(active ? -2.5 : 0))
    }
}
