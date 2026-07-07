import Foundation
import SwiftUI

// MARK: - Demo models (UI prototyping only; replaced by Supabase models later)

struct DemoMeal: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var mealType: String
    var time: String
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var icon: String
    var isSafe: Bool = true
}

struct DemoPattern: Identifiable {
    let id = UUID()
    var ingredient: String
    var symptom: String
    var occurrences: Int
    var exposures: Int
    var windowText: String
    var exerciseLinked: Bool
    var confidence: Double
}

struct DemoGroceryItem: Identifiable {
    let id = UUID()
    var name: String
    var quantity: String
    var checked: Bool = false
}

enum MockData {
    static let userName = "Eli"
    static let allergens = ["Peanut", "Dairy", "Sesame"]

    static let todayMeals: [DemoMeal] = [
        .init(name: "Oat & Blueberry Bowl", mealType: "Breakfast", time: "7:20 AM", calories: 420, protein: 22, carbs: 58, fat: 12, icon: "cup.and.saucer.fill"),
        .init(name: "Grilled Chicken + Rice", mealType: "Lunch", time: "12:45 PM", calories: 640, protein: 48, carbs: 70, fat: 16, icon: "fork.knife"),
        .init(name: "Pre-Workout Banana + SunButter", mealType: "Pre-workout", time: "4:30 PM", calories: 260, protein: 8, carbs: 38, fat: 9, icon: "bolt.fill"),
    ]

    static let planMeals: [DemoMeal] = [
        .init(name: "Steel-Cut Oats, Blueberries & Hemp Seeds", mealType: "Breakfast", time: "", calories: 460, protein: 24, carbs: 62, fat: 13, icon: "sunrise.fill"),
        .init(name: "Turkey & Avocado Rice Bowl", mealType: "Lunch", time: "", calories: 680, protein: 52, carbs: 68, fat: 20, icon: "sun.max.fill"),
        .init(name: "Banana + SunButter Toast (GF)", mealType: "Pre-workout", time: "", calories: 280, protein: 9, carbs: 42, fat: 9, icon: "bolt.fill"),
        .init(name: "Salmon, Sweet Potato & Broccoli", mealType: "Dinner", time: "", calories: 720, protein: 46, carbs: 58, fat: 28, icon: "moon.stars.fill"),
    ]

    static let swapAlternatives: [String: [String]] = [
        "Steel-Cut Oats, Blueberries & Hemp Seeds": ["Quinoa Breakfast Bowl with Berries", "Chia Pudding with Mango (coconut milk)"],
        "Turkey & Avocado Rice Bowl": ["Beef & Veggie Burrito Bowl (DF)", "Chicken Pesto Pasta (nut-free pesto)"],
        "Banana + SunButter Toast (GF)": ["Rice Cakes with Pumpkin Seed Butter", "Dates + Coconut Yogurt"],
        "Salmon, Sweet Potato & Broccoli": ["Herb Chicken, Roast Potatoes & Greens", "Beef Stir-Fry with Jasmine Rice"],
    ]

    static let patterns: [DemoPattern] = [
        .init(ingredient: "Whey protein", symptom: "GI distress", occurrences: 3, exposures: 4, windowText: "within 90 min of lifting", exerciseLinked: true, confidence: 0.75),
        .init(ingredient: "Granola bar (oat blend)", symptom: "Hives", occurrences: 2, exposures: 5, windowText: "within 3 hours", exerciseLinked: false, confidence: 0.40),
        .init(ingredient: "Almond flour crust", symptom: "Itching", occurrences: 2, exposures: 2, windowText: "within 1 hour", exerciseLinked: false, confidence: 0.95),
    ]

    static let groceryList: [DemoGroceryItem] = [
        .init(name: "Steel-cut oats", quantity: "1 lb"),
        .init(name: "Blueberries", quantity: "2 pints"),
        .init(name: "Hemp seeds", quantity: "8 oz"),
        .init(name: "Ground turkey", quantity: "2 lb"),
        .init(name: "Avocados", quantity: "4"),
        .init(name: "Jasmine rice", quantity: "2 lb"),
        .init(name: "SunButter", quantity: "1 jar"),
        .init(name: "GF bread", quantity: "1 loaf"),
        .init(name: "Salmon fillets", quantity: "4 × 6 oz"),
        .init(name: "Sweet potatoes", quantity: "3 lb"),
        .init(name: "Broccoli crowns", quantity: "2"),
    ]

    static let symptoms = ["Hives", "Itching", "GI distress", "Nausea", "Bloating", "Fatigue", "Headache", "Congestion", "Swelling", "Breathing", "Skin flush", "Dizziness"]

    static let allAllergens = ["Peanut", "Tree Nuts", "Milk / Dairy", "Egg", "Wheat", "Gluten", "Soy", "Fish", "Shellfish", "Sesame", "Corn", "Nightshades", "Histamine", "FODMAPs", "Sulfites", "Mustard", "Alpha-gal"]
}
