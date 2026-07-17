import SwiftUI

/// Shown once, the first time a user lands in the app, so "Volt" reads as a
/// named coach rather than unexplained branding scattered across screens.
struct VoltIntroSheet: View {
    @Environment(\.dismiss) private var dismiss

    private struct Capability: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let capabilities: [Capability] = [
        .init(icon: "camera.fill", title: "Snap a meal",
              detail: "Photo or a quick description — Volt works out the nutrition from the USDA database."),
        .init(icon: "sparkles", title: "Generate safe recipes",
              detail: "Every idea is pre-checked against your triggers before you see it."),
        .init(icon: "calendar", title: "Plan your week",
              detail: "A full day of meals around your targets, and the grocery list writes itself."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            ZStack {
                Circle()
                    .fill(Theme.Colors.volt)
                    .frame(width: 84, height: 84)
                    .shadow(color: Theme.Colors.volt.opacity(0.4), radius: 14, y: 6)
                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Theme.Colors.onVolt)
            }
            .padding(.bottom, 18)

            Text("Meet Volt")
                .font(Theme.Fonts.stat(30))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Your AI nutrition coach")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.volt)
                .padding(.bottom, 28)

            VStack(spacing: 16) {
                ForEach(capabilities) { cap in
                    HStack(spacing: 14) {
                        Image(systemName: cap.icon)
                            .font(.title3)
                            .foregroundStyle(Theme.Colors.volt)
                            .frame(width: 44, height: 44)
                            .background(Theme.Colors.volt.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cap.title)
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(cap.detail)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 4)

            Spacer(minLength: 24)

            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Text("Let's go")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.onVolt)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .pressable()
        }
        .padding(24)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .background(Theme.Colors.background.ignoresSafeArea())
    }
}
