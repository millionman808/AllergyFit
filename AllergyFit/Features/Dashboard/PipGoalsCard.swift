import SwiftUI

/// Today's goals, Finch style: a checklist under Pip. Food goals tick
/// themselves off from what you log; tapping them opens the logger instead.
/// Each goal pays seeds and fills Pip's energy bar.
struct PipGoalsCard: View {
    @ObservedObject var pip: FuelFriendStore
    let day: PipDaySnapshot
    var onLogFood: () -> Void
    var onTummyCheckIn: () -> Void
    var onAddWater: () -> Void

    @State private var showAddGoal = false
    @State private var newGoalTitle = ""
    @State private var justDone: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            energyBar
            VStack(spacing: 8) {
                ForEach(pip.goals) { goal in
                    row(goal)
                }
            }
            Button {
                newGoalTitle = ""
                showAddGoal = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add a goal")
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.finchMint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Theme.Colors.finchMint.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Metrics.cardPadding)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
            .strokeBorder(Theme.Colors.parchmentBorder.opacity(0.7), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 14, y: 5)
        .alert("Add a goal", isPresented: $showAddGoal) {
            TextField("e.g. Drink tea after dinner", text: $newGoalTitle)
            Button("Add") { pip.addGoal(title: newGoalTitle) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Something small you want to do today. \(pip.name) will cheer you on.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's goals")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Each one earns \(FuelFriendStore.seedsPerGoal) seeds for \(pip.name).")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Text("\(pip.goalsDoneCount)/\(pip.goals.count)")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.finchMint)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: pip.goalsDoneCount)
        }
    }

    private var energyBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Colors.finchButter)
                Text(energyLine)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text("\(Int(pip.energy))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Colors.surfaceRaised)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.Colors.finchButter, Theme.Colors.finchPeach],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(10, geo.size.width * pip.energy / 100))
                        .opacity(pip.energy > 0 ? 1 : 0)
                }
            }
            .frame(height: 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: pip.energy)
        }
    }

    private var energyLine: String {
        switch pip.adventureState {
        case "exploring": return "\(pip.name) is out on an adventure"
        case "completed_today": return "Adventure done for today"
        default:
            if pip.energy >= 100 { return "Energy full: adventure ready!" }
            let left = Int(ceil((100 - pip.energy) / FuelFriendStore.energyPerGoal))
            return "\(left) more goal\(left == 1 ? "" : "s") to send \(pip.name) exploring"
        }
    }

    // MARK: - Rows

    private func row(_ goal: PipGoal) -> some View {
        let done = pip.isDone(goal)
        let tint = tint(for: goal)
        return Button { tap(goal) } label: {
            HStack(spacing: 12) {
                Image(systemName: goal.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(done ? Color.white : tint)
                    .frame(width: 38, height: 38)
                    .background(done ? tint : tint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(done ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                        .strikethrough(done, color: Theme.Colors.textTertiary)
                        .lineLimit(2)
                    if let sub = subtitle(goal, done: done) {
                        Text(sub)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)

                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Theme.Colors.finchMint)
                        .scaleEffect(justDone == goal.id ? 1.25 : 1)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    HStack(spacing: 3) {
                        Image("icon_seed").resizable().scaledToFit().frame(width: 13, height: 13)
                        Text("+\(FuelFriendStore.seedsPerGoal)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Theme.Colors.surfaceRaised, in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(done ? Theme.Colors.finchMint.opacity(0.06) : Theme.Colors.background,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { pip.removeGoal(goal) } label: {
                Label("Remove goal", systemImage: "trash")
            }
        }
        .accessibilityLabel(goal.title)
        .accessibilityValue(done ? "Done" : "Not done")
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: done)
    }

    private func tap(_ goal: PipGoal) {
        switch goal.kind {
        case .breakfast, .lunch, .dinner, .protein:
            if !pip.isDone(goal) { onLogFood() }
        case .tummy:
            if !pip.isDone(goal) { onTummyCheckIn() }
        case .water:
            if !pip.isDone(goal) { onAddWater() }
        case .move, .manual:
            let wasDone = pip.isDone(goal)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { pip.toggle(goal) }
            if !wasDone { pulse(goal.id) }
        }
    }

    private func pulse(_ id: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { justDone = id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.3)) { if justDone == id { justDone = nil } }
        }
    }

    private func subtitle(_ goal: PipGoal, done: Bool) -> String? {
        if done { return "Done" }
        switch goal.kind {
        case .breakfast, .lunch, .dinner: return "Checks off when you log it"
        case .water: return "\(day.water) of \(day.waterGoal) glasses · tap to add one"
        case .protein: return "\(day.protein) of \(day.targetProtein)g"
        case .tummy: return "How did your stomach feel today?"
        case .move: return day.activeMinutes > 0 ? "\(day.activeMinutes) of 20 min · or tap when done" : "Tap when done"
        case .manual: return "Tap when done"
        }
    }

    private func tint(for goal: PipGoal) -> Color {
        switch goal.kind {
        case .breakfast: return Theme.Colors.finchButter
        case .lunch: return Theme.Colors.finchPeach
        case .dinner: return Theme.Colors.finchLavender
        case .water: return Theme.Colors.finchSky
        case .protein: return Theme.Colors.finchRose
        case .tummy, .manual: return Theme.Colors.finchMint
        case .move: return Theme.Colors.finchPeach
        }
    }
}
