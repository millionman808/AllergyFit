import Foundation

/// App-level configuration.
/// Only PUBLIC values live here (the publishable key is designed to ship in the client;
/// all data access is protected by Postgres Row-Level Security).
/// Secrets (Claude API key, Supabase secret key) live in Supabase Edge Functions only.
enum Config {
    static let supabaseURL = URL(string: "https://aamwutlbnrkymtovkucz.supabase.co")!
    static let supabasePublishableKey = "sb_publishable_xwuj3ZlSDj4zvw2OTDqwyw_MXiq3IbV"

    /// RevenueCat PUBLIC SDK key (starts with "appl_"). Safe to ship in the client.
    /// Paste yours from app.revenuecat.com → your app → API Keys.
    static let revenueCatKey = "appl_jyZGXAMfcVyaPOJIgeRTauJNdzN"

    /// Master switch for payments. Off: the app is completely free, no paywall,
    /// no StoreKit calls, no "Manage subscription" row. Turn on to bring back the
    /// hard paywall (RevenueCat products and offering are already set up).
    static let paymentsEnabled = false

    // Features held back from the 1.0 pre-order build. Flip to bring them back.
    /// Food Pals roster (companions have no artwork yet).
    static let foodPalsEnabled = false
    /// Cycle-aware fueling. Off also means no menstrual data is read from Health.
    static let cycleTrackingEnabled = false
    /// The AI "Ask" chat in the + sheet.
    static let askChatEnabled = false
    /// The new Figma Meals tab. Its food list, week strip and planned meals
    /// are still placeholders, so the tab shows the working PlanView until
    /// they're wired to real data.
    static let newMealsTabEnabled = true

    /// RevenueCat entitlement identifier that unlocks Premium.
    static let premiumEntitlement = "premium"
}
