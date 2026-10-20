import SwiftUI

/// Modern tactical status cards inspired by widget cards (Screen 1 from user brief).
/// Supports Large, Medium, and Compact layouts with real-time companion status,
/// dynamic action buttons, and circular 1-tap quick re-logs.
struct CompanionStatusCard: View {
    @ObservedObject var friendStore: FuelFriendStore = FuelFriendStore.shared
    @ObservedObject var todayStore: TodayStore

    var onLogMeal: () -> Void = {}
    var onHydrate: () -> Void = {}
    var onCheckFood: () -> Void = {}

    enum CardStyle {
        case largeWidget
        case mediumWidget
        case compactTile
    }

    var style: CardStyle = .largeWidget

    @EnvironmentObject private var session: SessionStore
    @ObservedObject private var recents = RecentFoods.shared

    /// Your four most recent foods, re-logged with the numbers you logged them with.
    private var recentQuickFoods: [FoodCatalogItem] { Array(recents.items.prefix(4)) }

    var body: some View {
        cardBody
            .task { await recents.load(session: session, today: todayStore) }
    }

    @ViewBuilder private var cardBody: some View {
        switch style {
        case .largeWidget:
            largeCard
        case .mediumWidget:
            mediumCard
        case .compactTile:
            compactCard
        }
    }

    // MARK: - Large Widget Card (Screen 1 Top)

    private var largeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Row: Avatar & Mode
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0x992B22)) // Deep crimson accent
                        .frame(width: 48, height: 48)
                    Image("pip_happy")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                }

                Spacer()

                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white.opacity(0.35))
            }

            // Location / Companion State
            VStack(alignment: .leading, spacing: 4) {
                Text(statusHeadline)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(statusSubline)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: 0xF08A5D)) // Coral peach alert
            }

            // Primary Action Button (Resume now / Log now)
            Button {
                Haptics.success()
                onLogMeal()
            } label: {
                Text("Log meal now")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: 0x3B66F5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            // Recents Strip
            VStack(alignment: .leading, spacing: 10) {
                Text("Recents")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.6))

                HStack(spacing: 12) {
                    ForEach(recentQuickFoods) { item in
                        Button {
                            Haptics.tap()
                            todayStore.addMeal(name: item.name, mealType: TodayStore.displayMealType(TodayStore.mealTypeForNow()),
                                               calories: item.baseCalories,
                                               protein: Int(item.baseProtein.rounded()),
                                               carbs: Int(item.baseCarbs.rounded()),
                                               fat: Int(item.baseFat.rounded()))
                            FuelFriendStore.shared.feed(mealName: item.name)
                        } label: {
                            quickCircle(icon: item.icon, caption: item.name)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Log \(item.name) again, \(item.baseCalories) calories")
                    }
                    Button {
                        Haptics.tap()
                        onHydrate()
                    } label: {
                        quickCircle(icon: "drop.fill", caption: "Water")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add a glass of water")
                }
            }
        }
        .padding(20)
        .background(Color(hex: 0x1E2024), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 14, y: 6)
    }

    private func quickCircle(icon: String, caption: String) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(Color(hex: 0x2A2E33))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
            }
            Text(caption.split(separator: ",").first.map(String.init) ?? caption)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.6))
                .lineLimit(1)
                .frame(width: 56)
        }
    }

    // MARK: - Medium Card (Screen 1 Middle)

    private var mediumCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0x992B22))
                        .frame(width: 44, height: 44)
                    Image("pip_happy")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusHeadline)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(statusSubline)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: 0xF08A5D))
                }

                Spacer()

                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.35))
            }

            Button {
                Haptics.success()
                onLogMeal()
            } label: {
                Text("Log meal now")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: 0x3B66F5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color(hex: 0x1E2024), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 10, y: 4)
    }

    // MARK: - Compact Tile (Screen 1 Bottom)

    private var compactCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0x992B22))
                        .frame(width: 36, height: 36)
                    Image("pip_happy")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }

                Spacer()

                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.35))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(friendStore.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Fueled")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: 0xF08A5D))
            }

            Button {
                Haptics.tap()
                onLogMeal()
            } label: {
                Text("Resume")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(hex: 0x3B66F5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(width: 140)
        .padding(14)
        .background(Color(hex: 0x1E2024), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
    }

    private var statusHeadline: String {
        "\(friendStore.name) · Level \(friendStore.level)"
    }

    private var statusSubline: String {
        let remaining = todayStore.remainingCalories
        if remaining > 0 {
            return "\(remaining) kcal left to nourish today"
        } else {
            return "Daily nutrition goal achieved!"
        }
    }
}
