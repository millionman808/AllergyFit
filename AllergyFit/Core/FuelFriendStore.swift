import SwiftUI

/// FuelFriendStore — powers your personal nutrition companion ("Pip")
/// Rooted in Meta Pattern 1 (The Human Pattern) & Meta Pattern 2 (The Behavior Stakes).
@MainActor
final class FuelFriendStore: ObservableObject {
    /// One Pip for the whole app. Every screen that logs food, water or a
    /// tummy check-in talks to this instance, so the Pip on Today reacts.
    static let shared = FuelFriendStore()

    @AppStorage("fuelFriendName") var name: String = "Pip"
    @AppStorage("fuelFriendPot") var pot: String = "pot_1"
    @AppStorage("fuelFriendSeeds") var seeds: Int = 120
    /// Today's energy, 0-100. Goals fill it; full energy sends Pip on an adventure.
    @AppStorage("fuelFriendEnergy") var energy: Double = 0
    @AppStorage("fuelFriendPetCount") var totalPets: Int = 0
    @AppStorage("selectedCompanionId") var selectedCompanionId: String = "pip_avocado"
    @AppStorage("unlockedPotsRaw") var unlockedPotsRaw: String = "pot_1"
    @AppStorage("equippedDecor") var equippedDecor: String = "decor_mug"
    @AppStorage("unlockedDecorRaw") var unlockedDecorRaw: String = "decor_mug"
    @AppStorage("adventureState") var adventureState: String = "ready"
    @AppStorage("activePostcardId") var activePostcardId: String = "card_herb_garden"
    @AppStorage("collectedPostcardsRaw") var collectedPostcardsRaw: String = "card_herb_garden"
    @AppStorage("adventureStartedAt") var adventureStartedAt: Double = 0
    // Daily goals (see PipGoals.swift)
    @AppStorage("pipGoalsJSON") var goalsJSON: String = ""
    @AppStorage("pipGoalsDay") var goalsDay: String = ""
    @AppStorage("pipGoalsDoneRaw") var goalsDoneRaw: String = ""
    @AppStorage("pipGoalStreak") var goalStreak: Int = 0
    @AppStorage("pipGoalStreakDay") var goalStreakDay: String = ""
    @AppStorage("fuelFriendXP") var xp: Int = 340

    var level: Int {
        max(1, (xp / 100) + 1)
    }

    var xpInCurrentLevel: Int {
        xp % 100
    }

    var growthStageTitle: String {
        switch level {
        case 1: return "Little Sprout"
        case 2...3: return "Growing Roots"
        case 4...6: return "Little Garden"
        case 7...10: return "Flourishing"
        default: return "Thriving Together"
        }
    }
    /// Bumped to fire confetti (PipConfettiLayer).
    @Published var confettiSmall = 0
    @Published var confettiBig = 0
    @Published var hearts: Int = 0
    @Published var isPetting: Bool = false
    @Published var activeAction: String = "idle"
    @Published var lastInteractionDate: Date = Date()
    @Published var customDialogueOverride: String? = nil

    private init() {
        if let testAction = UserDefaults.standard.string(forKey: "testCompanionAction"), !testAction.isEmpty {
            self.activeAction = testAction
        }
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-testCompanionAction"), idx + 1 < args.count {
            self.activeAction = args[idx + 1]
        }
        if let idx = args.firstIndex(of: "-testPot"), idx + 1 < args.count {
            self.pot = args[idx + 1]
        }
        if let idx = args.firstIndex(of: "-testSeeds"), idx + 1 < args.count, let s = Int(args[idx + 1]) {
            self.seeds = s
        }
        if let idx = args.firstIndex(of: "-testAdventureState"), idx + 1 < args.count {
            self.adventureState = args[idx + 1]
        }
        rolloverIfNewDay()
    }

    struct FoodCompanion: Identifiable, Equatable {
        let id: String
        let name: String
        let foodType: String
        let icon: String
        let description: String
        let unlockStreakDays: Int
        let perk: String
        let isUnlocked: Bool
    }

    var availableCompanions: [FoodCompanion] {
        [
            FoodCompanion(
                id: "pip_avocado",
                name: name,
                foodType: "Avocado Pal",
                icon: "leaf.fill",
                description: "Fitness enthusiast with retro headband & kicks. Loves healthy fats & PRs!",
                unlockStreakDays: 0,
                perk: "+10% Heart Motivation",
                isUnlocked: true
            ),
            FoodCompanion(
                id: "bolt_blueberry",
                name: "Bolt",
                foodType: "Wild Blueberry",
                icon: "circle.hexagongrid.fill",
                description: "High-antioxidant speedster. Sharpens memory & brain power!",
                unlockStreakDays: 7,
                perk: "Focus Fuel Boost",
                isUnlocked: false
            ),
            FoodCompanion(
                id: "sunny_citrus",
                name: "Sunny",
                foodType: "Golden Citrus",
                icon: "sun.max.fill",
                description: "Vitamin C sunshine dynamo. Keeps your immune shield impenetrable!",
                unlockStreakDays: 14,
                perk: "Shield Immunity +15%",
                isUnlocked: false
            ),
            FoodCompanion(
                id: "sprout_broccoli",
                name: "Sprout",
                foodType: "Baby Broccoli",
                icon: "tree.fill",
                description: "The micronutrient powerhouse. Always stretches before squatting!",
                unlockStreakDays: 21,
                perk: "Micronutrient Mastery",
                isUnlocked: false
            ),
            FoodCompanion(
                id: "oatley_grain",
                name: "Oatley",
                foodType: "Steel-Cut Oat",
                icon: "wind",
                description: "Steady energy champion. Fuels marathon endurance without crashing!",
                unlockStreakDays: 30,
                perk: "Sustained Glycogen Lock",
                isUnlocked: false
            )
        ]
    }

    // MARK: - Flower Pots (The Windowsill Pot Collection)
    struct FlowerPot: Identifiable, Equatable {
        let id: String
        let name: String
        let subtitle: String
        let cost: Int
        let accentColorHex: UInt
    }

    static let allPots: [FlowerPot] = [
        FlowerPot(id: "pot_1", name: "Terracotta", subtitle: "Warm Earth", cost: 0, accentColorHex: 0xD07C60),
        FlowerPot(id: "pot_2", name: "Sage Meadow", subtitle: "Soothing Leaf", cost: 50, accentColorHex: 0x8FA878),
        FlowerPot(id: "pot_3", name: "Buttercup", subtitle: "Golden Sun", cost: 60, accentColorHex: 0xE8B84B),
        FlowerPot(id: "pot_4", name: "Blush Bloom", subtitle: "Cozy Petal", cost: 60, accentColorHex: 0xE5989B),
        FlowerPot(id: "pot_5", name: "Morning Sky", subtitle: "Pastel Breeze", cost: 75, accentColorHex: 0x8CBAD9),
        FlowerPot(id: "pot_6", name: "Cream Dotted", subtitle: "Speckled Linen", cost: 75, accentColorHex: 0xD9C5B2)
    ]

    var unlockedPots: Set<String> {
        get {
            var set = Set(unlockedPotsRaw.split(separator: ",").map(String.init))
            set.insert(pot)
            set.insert("pot_1")
            return set
        }
        set {
            unlockedPotsRaw = newValue.joined(separator: ",")
            objectWillChange.send()
        }
    }

    func isPotUnlocked(_ id: String) -> Bool {
        unlockedPots.contains(id)
    }

    func equipPot(_ id: String) {
        guard isPotUnlocked(id) else { return }
        pot = id
        Haptics.tap()
        objectWillChange.send()
    }

    @discardableResult
    func buyAndEquipPot(_ potItem: FlowerPot) -> Bool {
        if isPotUnlocked(potItem.id) {
            equipPot(potItem.id)
            return true
        }
        guard seeds >= potItem.cost else {
            Haptics.warning()
            return false
        }
        seeds -= potItem.cost
        var set = unlockedPots
        set.insert(potItem.id)
        unlockedPots = set
        pot = potItem.id
        Haptics.success()
        activeAction = "celebrate"
        customDialogueOverride = "\(name) loves our new \(potItem.name) pot! Looking so fresh!"
        objectWillChange.send()
        return true
    }

    // MARK: - Windowsill Decor
    struct WindowsillDecor: Identifiable, Equatable {
        let id: String
        let name: String
        let subtitle: String
        let icon: String
        let cost: Int
        let tintHex: UInt
        let description: String
    }

    static let allDecor: [WindowsillDecor] = [
        WindowsillDecor(
            id: "decor_mug",
            name: "Matcha Ceramic Mug",
            subtitle: "Mindful Warmth",
            icon: "cup.and.saucer.fill",
            cost: 0,
            tintHex: 0x4E7D3F,
            description: "Steaming hot green tea to sip during peaceful morning reflections."
        ),
        WindowsillDecor(
            id: "decor_succulent",
            name: "Baby Jade Succulent",
            subtitle: "Gentle Oxygen",
            icon: "leaf.circle.fill",
            cost: 40,
            tintHex: 0x76A035,
            description: "A hardy, plump succulent that thrives in warm windowsill sunlight."
        ),
        WindowsillDecor(
            id: "decor_can",
            name: "Golden Watering Can",
            subtitle: "Daily Nourishment",
            icon: "drop.circle.fill",
            cost: 55,
            tintHex: 0xE8B84B,
            description: "A shiny brass spouted can for watering your sprout every morning."
        ),
        WindowsillDecor(
            id: "decor_herbs",
            name: "Kitchen Herb Jar",
            subtitle: "Garden Aroma",
            icon: "camera.macro",
            cost: 45,
            tintHex: 0x588157,
            description: "Freshly cut sweet basil and peppermint leaves for digestive comfort."
        ),
        WindowsillDecor(
            id: "decor_candle",
            name: "Beeswax Honey Candle",
            subtitle: "Evening Calm",
            icon: "flame.fill",
            cost: 60,
            tintHex: 0xF4A261,
            description: "Casts a warm honeyed glow when winding down for nighttime rest."
        ),
        WindowsillDecor(
            id: "decor_crystal",
            name: "Sunlight Prism",
            subtitle: "Rainbow Glow",
            icon: "sparkles",
            cost: 80,
            tintHex: 0x9B5DE5,
            description: "Catches early morning rays and casts dancing rainbows across the kitchen."
        )
    ]

    var unlockedDecor: Set<String> {
        get {
            var set = Set(unlockedDecorRaw.split(separator: ",").map(String.init))
            if !equippedDecor.isEmpty { set.insert(equippedDecor) }
            set.insert("decor_mug")
            return set
        }
        set {
            unlockedDecorRaw = newValue.joined(separator: ",")
            objectWillChange.send()
        }
    }

    func isDecorUnlocked(_ id: String) -> Bool {
        unlockedDecor.contains(id)
    }

    func equipDecor(_ id: String?) {
        if let id = id, !id.isEmpty {
            guard isDecorUnlocked(id) else { return }
            equippedDecor = id
        } else {
            equippedDecor = ""
        }
        Haptics.tap()
        objectWillChange.send()
    }

    @discardableResult
    func buyAndEquipDecor(_ item: WindowsillDecor) -> Bool {
        if isDecorUnlocked(item.id) {
            equipDecor(item.id)
            return true
        }
        guard seeds >= item.cost else {
            Haptics.warning()
            return false
        }
        seeds -= item.cost
        var set = unlockedDecor
        set.insert(item.id)
        unlockedDecor = set
        equippedDecor = item.id
        Haptics.success()
        activeAction = "celebrate"
        customDialogueOverride = "Our windowsill looks so cozy with the \(item.name)!"
        objectWillChange.send()
        return true
    }

    func addSeeds(_ count: Int, reason: String? = nil) {
        seeds += count
        if reason != nil {
            Haptics.tap()
        }
        objectWillChange.send()
    }

    // MARK: - Adventures & Collectible Postcards (Finch Adventure Meta-Pattern)
    struct Postcard: Identifiable, Equatable {
        let id: String
        let destination: String
        let locationTag: String
        let icon: String
        let accentColorHex: UInt
        let story: String
        let prompt: String
        let choices: [String]
        let dateEarned: String
    }

    static let allDestinations: [Postcard] = [
        Postcard(
            id: "card_berry_farm",
            destination: "Wildberry Patch",
            locationTag: "Sunny Foothills",
            icon: "leaf.circle.fill",
            accentColorHex: 0x9B5DE5,
            story: "Pip strolled through the brambles and met a friendly hummingbird! The ripe blackberries were deep purple with anthocyanin antioxidants.",
            prompt: "What berry would you add to your morning fuel?",
            choices: ["Wild Blackberries", "Sweet Strawberries"],
            dateEarned: "Spring Season"
        ),
        Postcard(
            id: "card_herb_garden",
            destination: "Aromatic Herb Garden",
            locationTag: "Cottage Valley",
            icon: "camera.macro",
            accentColorHex: 0x4E7D3F,
            story: "Pip sat on a warm stone bench surrounded by fresh peppermint and sweet basil. Breathing in the cool herbal air brought total peace to our tummy.",
            prompt: "Which herb scent calms your mind the most?",
            choices: ["Fresh Peppermint", "Soothing Lavender"],
            dateEarned: "Sunny Afternoon"
        ),
        Postcard(
            id: "card_citrus_grove",
            destination: "Golden Citrus Grove",
            locationTag: "Valencia Terraces",
            icon: "sun.max.fill",
            accentColorHex: 0xE8B84B,
            story: "Pip rested beneath a flowering orange tree. The golden citrus glowed like little suns in the morning mist, packed with vibrant vitamin C!",
            prompt: "How do you like to get your morning vitamin C?",
            choices: ["Fresh Squeezed Juice", "Crisp Apple Slices"],
            dateEarned: "Golden Morning"
        ),
        Postcard(
            id: "card_spring_waters",
            destination: "Crystal Hydration Springs",
            locationTag: "Mountain Creek",
            icon: "drop.fill",
            accentColorHex: 0x8CBAD9,
            story: "Pip took off their sneakers and dipped their little toes in the cool, sparkling spring. Staying hydrated keeps all our cells singing with energy!",
            prompt: "What helps you stay most hydrated during busy days?",
            choices: ["Ice-Cold Water Bottle", "Herbal Iced Tea"],
            dateEarned: "Mountain Retreat"
        ),
        Postcard(
            id: "card_farmers_market",
            destination: "Bustling Farmers Market",
            locationTag: "Town Square",
            icon: "basket.fill",
            accentColorHex: 0xD07C60,
            story: "Pip checked every wooden crate for fresh greens and root veggies. The farmers were so proud of growing food without harmful additives!",
            prompt: "What's your go-to fresh vegetable to cook with?",
            choices: ["Crisp Bell Peppers", "Tender Broccoli"],
            dateEarned: "Weekend Market"
        ),
        Postcard(
            id: "card_sunlit_meadow",
            destination: "Dandelion Meadow",
            locationTag: "Breeze Plateau",
            icon: "sparkles",
            accentColorHex: 0xE5989B,
            story: "Pip ran through field grasses and made a wish on a dandelion puff. Caring for your body with good nutrition is a gift you give your future self!",
            prompt: "What self-care win are you most proud of today?",
            choices: ["Eating Clean Macros", "Listening to My Body"],
            dateEarned: "Sunset Stroll"
        )
    ]

    var collectedPostcards: Set<String> {
        get {
            var set = Set(collectedPostcardsRaw.split(separator: ",").map(String.init))
            set.insert("card_herb_garden")
            return set
        }
        set {
            collectedPostcardsRaw = newValue.joined(separator: ",")
            objectWillChange.send()
        }
    }

    /// Stories are written about "Pip"; show them with the name the user chose.
    func personalized(_ text: String) -> String {
        text.replacingOccurrences(of: "Pip", with: name)
    }

    var currentPostcard: Postcard {
        Self.allDestinations.first(where: { $0.id == activePostcardId }) ?? Self.allDestinations[0]
    }

    /// How long Pip is away before the letter arrives.
    static let adventureDuration: TimeInterval = 90

    var canStartAdventure: Bool { adventureState == "ready" && energy >= 100 }

    /// Seconds until Pip is back; 0 once the letter has arrived.
    func adventureSecondsLeft(at now: Date = Date()) -> Int {
        guard adventureState == "exploring" else { return 0 }
        let back = adventureStartedAt + Self.adventureDuration
        return max(0, Int((back - now.timeIntervalSince1970).rounded(.up)))
    }

    func startAdventure() {
        guard canStartAdventure else { return }
        let uncollected = Self.allDestinations.filter { !collectedPostcards.contains($0.id) }
        let nextCard = uncollected.randomElement() ?? Self.allDestinations.randomElement() ?? Self.allDestinations[0]
        activePostcardId = nextCard.id
        adventureState = "exploring"
        adventureStartedAt = Date().timeIntervalSince1970
        energy = 0
        activeAction = "celebrate"
        Haptics.success()
        customDialogueOverride = "\(name) packed a snack and is off to \(nextCard.destination). Back soon with a letter!"
        objectWillChange.send()
    }

    func claimAdventureReward(choice: String) {
        var set = collectedPostcards
        set.insert(activePostcardId)
        collectedPostcards = set
        adventureState = "completed_today"
        addSeeds(30, reason: "Adventure Postcard Reward")
        xp += 30
        activeAction = "celebrate"
        confettiBig += 1
        Haptics.success()
        customDialogueOverride = "\(name) returned from \(currentPostcard.destination)! Added a postcard & earned +30 Seeds!"
        objectWillChange.send()
    }

    func celebrateGoodCheckIn() {
        completeGoal(kind: .tummy)
        activeAction = "celebrate"
        Haptics.success()
        customDialogueOverride = "Awesome! A calm and happy tummy keeps \(name) smiling all day!"
        objectWillChange.send()
    }

    enum Mood: String, CaseIterable {
        case hungry = "Hungry"
        case happy = "Happy"
        case energized = "Energized"
        case hydrated = "Hydrated"
        case strong = "Strong"
        case sleepy = "Sleepy"
        case shielded = "Shielded"

        var icon: String {
            switch self {
            case .hungry: return "fork.knife"
            case .happy: return "sparkles"
            case .energized: return "bolt.fill"
            case .hydrated: return "drop.fill"
            case .strong: return "dumbbell.fill"
            case .sleepy: return "moon.stars.fill"
            case .shielded: return "checkmark.shield.fill"
            }
        }
    }

    /// Pet the companion — triggers joyful micro-bounce, haptics, and affectionate message.
    func pet() {
        totalPets += 1
        hearts += 1
        isPetting = true
        activeAction = "celebrate"
        Haptics.success()

        let petPhrases = [
            "\(name) flexes its little avocado arms! 'Crushing our fuel goals!'",
            "\(name) tightens its headband! 'Ready to power through today!'",
            "\(name) taps its sneakers happily: 'You're the best workout buddy ever!'",
            "\(name) does a joyful wiggle! 'Healthy fats, clean macros, big energy!'",
            "\(name) beams with pride! 'Every healthy choice fuels us both!'"
        ]
        customDialogueOverride = petPhrases.randomElement()

        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                withAnimation(.spring(response: 0.35)) {
                    if self.customDialogueOverride != nil {
                        self.customDialogueOverride = nil
                    }
                    self.isPetting = false
                    if self.activeAction == "celebrate" {
                        self.activeAction = "idle"
                    }
                }
            }
        }
    }

    /// Companion feeding reaction (Meta Pattern 2: Emotional behavior stakes)
    func feed(mealName: String) {
        hearts += 2
        totalPets += 1
        xp += 15
        isPetting = true
        activeAction = "eat"
        Haptics.success()

        let feedPhrases = [
            "Yum! Thanks for taking care of yourself.",
            "Nom nom nom! \(name) munched on \(mealName) and is glowing with joy!",
            "Delicious! \(name) loved the \(mealName). 'My tummy feels so happy and safe!'",
            "Mmm! \(name) happily ate \(mealName). You're such an attentive friend!",
            "Yum! That \(mealName) hit the spot. \(name)'s fuel bar is up!"
        ]
        customDialogueOverride = feedPhrases.randomElement()

        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                withAnimation(.spring(response: 0.35)) {
                    if self.customDialogueOverride != nil {
                        self.customDialogueOverride = nil
                    }
                    self.isPetting = false
                    if self.activeAction == "eat" {
                        self.activeAction = "idle"
                    }
                }
            }
        }
    }

    /// Companion hydration reaction
    func hydrate() {
        hearts += 1
        xp += 5
        activeAction = "drink"
        Haptics.tap()

        let waterPhrases = [
            "A little drink goes a long way!",
            "Glug glug glug! Ahh, \(name) feels refreshed and revitalized!",
            "Crisp & cool! \(name) clinks glasses with you: 'Stay hydrated, bestie!'",
            "Hydration boost! \(name) does a happy dance with a full water cup!"
        ]
        customDialogueOverride = waterPhrases.randomElement()

        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                withAnimation(.spring(response: 0.35)) {
                    if self.customDialogueOverride != nil {
                        self.customDialogueOverride = nil
                    }
                    if self.activeAction == "drink" {
                        self.activeAction = "idle"
                    }
                }
            }
        }
    }

    /// Companion tummy bloated reaction (e.g. user checks in on feeling bloated or logs a food reaction)
    func triggerBloatedReaction(reason: String = "tummy sensitivity", countsAsCheckIn: Bool = false) {
        // Logging a rough day is still a check-in: it's how triggers get found.
        if countsAsCheckIn { completeGoal(kind: .tummy) }
        activeAction = "bloated"
        Haptics.warning()
        customDialogueOverride = "Oof... \(name)'s tummy feels a bit grumbly and bloated too. Let's sip warm water and rest!"
        Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            await MainActor.run {
                withAnimation(.spring(response: 0.35)) {
                    if self.customDialogueOverride?.contains("tummy") == true {
                        self.customDialogueOverride = nil
                    }
                    if self.activeAction == "bloated" {
                        self.activeAction = "idle"
                    }
                }
            }
        }
    }

    /// Derive companion mood from user's current day metrics
    func currentMood(calories: Int, targetCalories: Int, protein: Int, targetProtein: Int, water: Int, waterGoal: Int) -> Mood {
        let hour = Calendar.current.component(.hour, from: Date())

        if hour >= 21 || hour < 5 {
            return .sleepy
        }
        if calories == 0 {
            return .hungry
        }
        if Double(protein) >= Double(targetProtein) * 0.8 && targetProtein > 0 {
            return .strong
        }
        if Double(water) >= Double(waterGoal) * 0.75 && waterGoal > 0 {
            return .hydrated
        }
        if Double(calories) >= Double(targetCalories) * 0.5 {
            return .energized
        }
        return .happy
    }

    /// Dynamic dialogue based on Meta Pattern 1 (Carrot Weather / Finch):
    /// The character's emotional reaction replaces raw cold data as the headline.
    func dialogue(
        calories: Int,
        targetCalories: Int,
        protein: Int,
        targetProtein: Int,
        water: Int,
        waterGoal: Int,
        mealCount: Int,
        allergens: [String]
    ) -> String {
        if let override = customDialogueOverride {
            return override
        }

        let hour = Calendar.current.component(.hour, from: Date())
        let allergenList = allergens.joined(separator: ", ")

        // 1. Morning state
        if hour < 11 && mealCount == 0 {
            if allergenList.isEmpty {
                return "Good morning! My tummy is rumbling... What delicious breakfast are we whipping up today?"
            } else {
                return "Good morning! Let's start the day with a nourishing breakfast free of \(allergenList)!"
            }
        }

        // 2. Sleepy nighttime state
        if hour >= 21 {
            return "Yaaawn... We fueled like absolute champions today. Time to tuck in and rest our tummies!"
        }

        // 3. Low hydration call-out
        if water < 3 && hour >= 13 {
            return "Psst! My water cup is almost dry. Let's sip a tall glass together!"
        }

        // 4. Strong protein celebration
        if targetProtein > 0 && Double(protein) >= Double(targetProtein) * 0.85 {
            return "Look at these muscles! \(protein)g of clean protein logged—our muscles are repairing in prime form!"
        }

        // 5. Well-fueled afternoon
        if Double(calories) >= Double(targetCalories) * 0.65 {
            return "We are so well fueled! Energy bar is glowing. Today is officially a great food day!"
        }

        // 6. First meal logged
        if mealCount == 1 {
            return "Mmm, that was delicious! Tummy is warm and happy!"
        }

        // Default supportive check-in
        return "Hey bestie! Checking in—remember to eat slowly, chew well, and celebrate your body!"
    }
}
