import SwiftUI

/// FuelFriendStore — powers your personal nutrition companion ("Pip")
/// Rooted in Meta Pattern 1 (The Human Pattern) & Meta Pattern 2 (The Behavior Stakes).
@MainActor
final class FuelFriendStore: ObservableObject {
    @AppStorage("fuelFriendName") var name: String = "Pip"
    @AppStorage("fuelFriendPetCount") var totalPets: Int = 0
    @AppStorage("selectedCompanionId") var selectedCompanionId: String = "pip_avocado"
    @Published var hearts: Int = 0
    @Published var isPetting: Bool = false
    @Published var activeAction: String = "idle"
    @Published var lastInteractionDate: Date = Date()
    @Published var customDialogueOverride: String? = nil

    init() {
        if let testAction = UserDefaults.standard.string(forKey: "testCompanionAction"), !testAction.isEmpty {
            self.activeAction = testAction
        }
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-testCompanionAction"), idx + 1 < args.count {
            self.activeAction = args[idx + 1]
        }
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
                icon: "🥑",
                description: "Fitness enthusiast with retro headband & kicks. Loves healthy fats & PRs!",
                unlockStreakDays: 0,
                perk: "+10% Heart Motivation",
                isUnlocked: true
            ),
            FoodCompanion(
                id: "bolt_blueberry",
                name: "Bolt",
                foodType: "Wild Blueberry",
                icon: "🫐",
                description: "High-antioxidant speedster. Sharpens memory & brain power!",
                unlockStreakDays: 7,
                perk: "Focus Fuel Boost",
                isUnlocked: false
            ),
            FoodCompanion(
                id: "sunny_citrus",
                name: "Sunny",
                foodType: "Golden Citrus",
                icon: "🍊",
                description: "Vitamin C sunshine dynamo. Keeps your immune shield impenetrable!",
                unlockStreakDays: 14,
                perk: "Shield Immunity +15%",
                isUnlocked: false
            ),
            FoodCompanion(
                id: "sprout_broccoli",
                name: "Sprout",
                foodType: "Baby Broccoli",
                icon: "🥦",
                description: "The micronutrient powerhouse. Always stretches before squatting!",
                unlockStreakDays: 21,
                perk: "Micronutrient Mastery",
                isUnlocked: false
            ),
            FoodCompanion(
                id: "oatley_grain",
                name: "Oatley",
                foodType: "Steel-Cut Oat",
                icon: "🌾",
                description: "Steady energy champion. Fuels marathon endurance without crashing!",
                unlockStreakDays: 30,
                perk: "Sustained Glycogen Lock",
                isUnlocked: false
            )
        ]
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
            "\(name) flexes its little avocado arms! 'Crushing our fuel goals!' 🥑✨",
            "\(name) tightens its headband! 'Ready to power through today!' 💪",
            "\(name) taps its sneakers happily: 'You're the best workout buddy ever!' 👟💚",
            "\(name) does a joyful wiggle! 'Healthy fats, clean macros, big energy!' 🥑🌟",
            "\(name) beams with pride! 'Every healthy choice fuels us both!' 🏆"
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
        isPetting = true
        activeAction = "eat"
        Haptics.success()

        let feedPhrases = [
            "Nom nom nom! \(name) munched on \(mealName) and is glowing with joy! ✨",
            "Delicious! \(name) loved the \(mealName). 'My tummy feels so happy and safe!' 🥣",
            "Mmm! \(name) happily ate \(mealName). You're such an attentive friend! 🥑",
            "Yum! That \(mealName) hit the spot. \(name)'s fuel bar is up! 🔋"
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
        activeAction = "drink"
        Haptics.tap()

        let waterPhrases = [
            "Glug glug glug! Ahh, \(name) feels refreshed and revitalized! 💧",
            "Crisp & cool! \(name) clinks glasses with you: 'Stay hydrated, bestie!' 🧊",
            "Hydration boost! \(name) does a happy dance with a full water cup! 🌊"
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
                return "Good morning! My tummy is rumbling... What delicious breakfast are we whipping up today? 🥞"
            } else {
                return "Good morning! Let's start the day with a nourishing breakfast free of \(allergenList)! 🍳"
            }
        }

        // 2. Sleepy nighttime state
        if hour >= 21 {
            return "Yaaawn... We fueled like absolute champions today. Time to tuck in and rest our tummies! 🌙"
        }

        // 3. Low hydration call-out
        if water < 3 && hour >= 13 {
            return "Psst! My water cup is almost dry. Let's sip a tall glass together! 💧"
        }

        // 4. Strong protein celebration
        if targetProtein > 0 && Double(protein) >= Double(targetProtein) * 0.85 {
            return "Look at these muscles! \(protein)g of clean protein logged—our muscles are repairing in prime form! 💪"
        }

        // 5. Well-fueled afternoon
        if Double(calories) >= Double(targetCalories) * 0.65 {
            return "We are so well fueled! Energy bar is glowing. Today is officially a great food day! 🌟"
        }

        // 6. First meal logged
        if mealCount == 1 {
            return "Mmm, that was delicious! Tummy is warm and our allergen shield kept us 100% safe! 🥣"
        }

        // Default supportive check-in
        return "Hey bestie! Checking in—remember to eat slowly, chew well, and celebrate your body! 🌿"
    }
}
