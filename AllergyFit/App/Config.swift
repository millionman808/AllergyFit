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

    /// RevenueCat entitlement identifier that unlocks Premium.
    static let premiumEntitlement = "premium"
}
