import SwiftUI

// MARK: - Skeleton loaders (#22 Speed perception)
// Shows the *shape* of content while it loads so the app feels instant and smooth.

/// A moving highlight sweep applied over a placeholder shape.
struct Shimmer: ViewModifier {
    @State private var offset: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.28), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.7)
                    .offset(x: offset * geo.size.width * 1.7)
                }
                .allowsHitTesting(false)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
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

/// Placeholder for food rows in meal logger
struct SkeletonFoodRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonBlock(cornerRadius: 14)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(cornerRadius: 6)
                    .frame(width: 160, height: 14)
                SkeletonBlock(cornerRadius: 5)
                    .frame(width: 100, height: 11)
            }
            Spacer()
            SkeletonBlock(cornerRadius: 12)
                .frame(width: 34, height: 34)
        }
        .padding(14)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Placeholder for Daily Intake Macro Header (Image 3)
struct SkeletonMacroHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SkeletonBlock(cornerRadius: 6).frame(width: 90, height: 14)
                Spacer()
                SkeletonBlock(cornerRadius: 6).frame(width: 80, height: 14)
            }
            SkeletonBlock(cornerRadius: 5).frame(height: 8)
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBlock(cornerRadius: 4).frame(width: 40, height: 10)
                        SkeletonBlock(cornerRadius: 4).frame(height: 6)
                        SkeletonBlock(cornerRadius: 4).frame(width: 50, height: 10)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Full placeholder for the Lifesum Meal Logger Screen
struct SkeletonMealLogger: View {
    var body: some View {
        VStack(spacing: 16) {
            SkeletonMacroHeader()
            SkeletonBlock(cornerRadius: 16).frame(height: 52)
            VStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonFoodRow()
                }
            }
        }
    }
}

/// Placeholder for Food Detail Screen (Image 4)
struct SkeletonFoodDetail: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                SkeletonBlock(cornerRadius: 8).frame(width: 220, height: 22)
                SkeletonBlock(cornerRadius: 6).frame(width: 140, height: 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                SkeletonBlock(cornerRadius: 12).frame(width: 60, height: 44)
                SkeletonBlock(cornerRadius: 12).frame(height: 44)
            }

            SkeletonBlock(cornerRadius: 12).frame(height: 44)

            HStack(spacing: 20) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 8) {
                        SkeletonBlock(cornerRadius: 35).frame(width: 70, height: 70)
                        SkeletonBlock(cornerRadius: 5).frame(width: 45, height: 12)
                        SkeletonBlock(cornerRadius: 5).frame(width: 35, height: 10)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 10)

            SkeletonBlock(cornerRadius: 20).frame(height: 140)
        }
        .padding(20)
    }
}
