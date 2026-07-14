import SwiftUI

// MARK: - Skeleton loaders (#22 Speed perception)
// Shows the *shape* of content while it loads so the app feels instant.

/// A moving highlight sweep applied over a placeholder shape.
struct Shimmer: ViewModifier {
    @State private var offset: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.16), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: offset * geo.size.width * 1.6)
                }
                .allowsHitTesting(false)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    offset = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
}

/// A single shimmering placeholder block.
struct SkeletonBlock: View {
    var cornerRadius: CGFloat = 8
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Theme.Colors.surfaceRaised)
            .shimmering()
    }
}

/// Placeholder that mirrors a real RecipeCard (image + title + subtitle).
struct SkeletonRecipeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SkeletonBlock(cornerRadius: 0)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock().frame(width: 190, height: 14)
                SkeletonBlock().frame(width: 130, height: 11)
            }
            .padding(12)
        }
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
    }
}
