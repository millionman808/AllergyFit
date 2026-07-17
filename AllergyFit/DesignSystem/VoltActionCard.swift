import SwiftUI

/// The one shared signature for every Volt AI action — recipe generation, day
/// planning, and anywhere else the coach does the work. A single look (sparkles
/// in a solid volt circle) teaches users "this is Volt / AI" at a glance, so the
/// AI entry points read as siblings instead of unrelated buttons.
struct VoltActionCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(Theme.Colors.onVolt)
                .frame(width: 40, height: 40)
                .background(Theme.Colors.volt, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(subtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.textTertiary)
        }
        .card()
    }
}
