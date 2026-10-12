import SwiftUI

/// Finch's core loop, for food: small daily goals. Each one checked off earns
/// seeds and fills Pip's energy; a full bar sends Pip on an adventure.
///
/// Food goals check themselves off from what you log (a breakfast, the water
/// goal, the protein target), so the app rewards the logging it needs.
/// Everything else is a tap, like Finch, and people can add their own.
struct PipGoal: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case breakfast, lunch, dinner, water, protein, tummy, move, manual
    }
    let id: String
    var title: String
    var icon: String
    var kind: Kind

    /// Food and water goals complete from logged data, not a tap.
    var isAutomatic: Bool {
        switch kind {
        case .breakfast, .lunch, .dinner, .water, .protein, .tummy: return true
        case .move, .manual: return false
        }
    }

    static let defaults: [PipGoal] = [
        PipGoal(id: "breakfast", title: "Log breakfast", icon: "sunrise.fill", kind: .breakfast),
        PipGoal(id: "lunch", title: "Log lunch", icon: "sun.max.fill", kind: .lunch),
        PipGoal(id: "dinner", title: "Log dinner", icon: "moon.stars.fill", kind: .dinner),
        PipGoal(id: "water", title: "Drink your water", icon: "drop.fill", kind: .water),
        PipGoal(id: "protein", title: "Hit your protein", icon: "bolt.heart.fill", kind: .protein),
        PipGoal(id: "tummy", title: "Check in on your tummy", icon: "leaf.fill", kind: .tummy),
        PipGoal(id: "move", title: "Move for 20 minutes", icon: "figure.walk", kind: .move),
        PipGoal(id: "green", title: "Eat something green", icon: "carrot.fill", kind: .manual),
    ]
}

/// What the dashboard knows about today, used to tick off automatic goals.
struct PipDaySnapshot: Equatable {
    var mealTypes: [String]
    var water: Int
    var waterGoal: Int
    var protein: Int
    var targetProtein: Int
    var activeMinutes: Int
}

extension FuelFriendStore {
    static let seedsPerGoal = 5
    static let energyPerGoal = 25.0
    static let perfectDayBonus = 20
    static let maxGoalTitleLength = 40

    private static func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Goals list

    var goals: [PipGoal] {
        guard let data = goalsJSON.data(using: .utf8),
              let list = try? JSONDecoder().decode([PipGoal].self, from: data), !list.isEmpty else {
            return PipGoal.defaults
        }
        return list
    }

    private func saveGoals(_ list: [PipGoal]) {
        if let data = try? JSONEncoder().encode(list) {
            goalsJSON = String(decoding: data, as: UTF8.self)
        }
        objectWillChange.send()
    }

    var completedGoalIDs: Set<String> {
        Set(goalsDoneRaw.split(separator: ",").map(String.init))
    }

    func isDone(_ goal: PipGoal) -> Bool { completedGoalIDs.contains(goal.id) }

    var goalsDoneCount: Int { goals.filter(isDone).count }

    // MARK: - Day rollover

    /// Goals, energy and the adventure are per day. Call on launch and foreground.
    func rolloverIfNewDay() {
        let today = Self.dayKey()
        guard goalsDay != today else { return }
        goalsDay = today
        goalsDoneRaw = ""
        energy = 0
        // A finished adventure resets; an unread letter waits for you.
        if adventureState == "completed_today" { adventureState = "ready" }
        objectWillChange.send()
    }

    // MARK: - Completing

    func completeGoal(kind: PipGoal.Kind) {
        rolloverIfNewDay()
        for goal in goals where goal.kind == kind { complete(goal) }
    }

    /// Tap on a goal row. Automatic goals can't be ticked by hand; manual ones
    /// toggle, and un-ticking gives back what it earned.
    func toggle(_ goal: PipGoal) {
        rolloverIfNewDay()
        guard !goal.isAutomatic else { return }
        if isDone(goal) { uncomplete(goal) } else { complete(goal) }
    }

    private func complete(_ goal: PipGoal) {
        guard !isDone(goal) else { return }
        var done = completedGoalIDs
        done.insert(goal.id)
        goalsDoneRaw = done.sorted().joined(separator: ",")
        seeds += Self.seedsPerGoal
        energy = min(100, energy + Self.energyPerGoal)
        bumpStreak()

        let allDone = goals.allSatisfy { done.contains($0.id) }
        if allDone {
            seeds += Self.perfectDayBonus
            confettiBig += 1
            Haptics.success()
            say("Every goal done! \(name) is doing a happy dance. +\(Self.seedsPerGoal + Self.perfectDayBonus) seeds.")
        } else {
            confettiSmall += 1
            Haptics.success()
            if energy >= 100 && adventureState == "ready" {
                say("\(name)'s energy is full! Send \(name) on an adventure.")
            } else {
                say(Self.cheers.randomElement()!.replacingOccurrences(of: "{name}", with: name)
                    + " +\(Self.seedsPerGoal) seeds.")
            }
        }
        activeAction = "celebrate"
        objectWillChange.send()
    }

    private func uncomplete(_ goal: PipGoal) {
        var done = completedGoalIDs
        guard done.remove(goal.id) != nil else { return }
        goalsDoneRaw = done.sorted().joined(separator: ",")
        seeds = max(0, seeds - Self.seedsPerGoal)
        // Energy already spent on an adventure stays spent.
        if adventureState == "ready" { energy = max(0, energy - Self.energyPerGoal) }
        Haptics.tap()
        objectWillChange.send()
    }

    /// Streak = days in a row with at least one goal done, like Finch.
    private func bumpStreak() {
        let today = Self.dayKey()
        guard goalStreakDay != today else { return }
        let yesterday = Self.dayKey(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        goalStreak = (goalStreakDay == yesterday) ? goalStreak + 1 : 1
        goalStreakDay = today
    }

    /// The streak shown today: still alive if the last goal day was yesterday.
    var currentGoalStreak: Int {
        let today = Self.dayKey()
        let yesterday = Self.dayKey(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        return (goalStreakDay == today || goalStreakDay == yesterday) ? goalStreak : 0
    }

    private static let cheers = [
        "Nice one! {name} is so proud of you.",
        "Look at you go! {name} did a little spin.",
        "That's how it's done. {name} feels great.",
        "Another one down! {name} is cheering.",
        "Yes! {name} gave you a high five.",
    ]

    private func say(_ line: String) {
        customDialogueOverride = line
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if self.customDialogueOverride == line { self.customDialogueOverride = nil }
        }
    }

    // MARK: - Automatic goals

    /// Ticks off automatic goals that today's data now satisfies. Never
    /// un-ticks: a deleted meal shouldn't take seeds back mid-celebration.
    func syncAutomaticGoals(_ day: PipDaySnapshot) {
        rolloverIfNewDay()
        let types = day.mealTypes.map { $0.lowercased() }
        for goal in goals where goal.isAutomatic && !isDone(goal) {
            let met: Bool
            switch goal.kind {
            case .breakfast: met = types.contains { $0.contains("breakfast") }
            case .lunch: met = types.contains { $0.contains("lunch") }
            case .dinner: met = types.contains { $0.contains("dinner") }
            case .water: met = day.waterGoal > 0 && day.water >= day.waterGoal
            case .protein: met = day.targetProtein > 0 && day.protein >= day.targetProtein
            case .tummy, .move, .manual: met = false
            }
            if met { complete(goal) }
        }
        // Moving can be ticked by hand, or comes in from Apple Health.
        if day.activeMinutes >= 20 {
            for goal in goals where goal.kind == .move { complete(goal) }
        }
    }

    // MARK: - Editing

    func addGoal(title: String) {
        let trimmed = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxGoalTitleLength))
        guard !trimmed.isEmpty else { return }
        var list = goals
        list.append(PipGoal(id: "custom_\(UUID().uuidString.prefix(8))", title: trimmed, icon: "star.fill", kind: .manual))
        saveGoals(list)
        Haptics.tap()
    }

    func removeGoal(_ goal: PipGoal) {
        var list = goals
        list.removeAll { $0.id == goal.id }
        // Keep at least one goal so the card never goes empty.
        saveGoals(list.isEmpty ? PipGoal.defaults : list)
    }

    func restoreDefaultGoals() {
        let custom = goals.filter { $0.id.hasPrefix("custom_") }
        saveGoals(PipGoal.defaults + custom)
    }
}
