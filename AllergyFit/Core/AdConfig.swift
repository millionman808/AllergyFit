import Foundation

/// Every ad-network identifier in one place.
///
/// All of these ship in the binary by design (they are client keys, not
/// secrets). A network whose IDs are empty is skipped entirely — no SDK
/// start, no events, no ATT prompt — so the app runs cleanly before the
/// accounts exist. Release builds refuse to archive while any are empty
/// (see the "Ad IDs configured" build phase) so a binary that declares
/// tracking but never asks for it can't reach App Review.
enum AdConfig {
    static let appleAppID = "6789274126"

    // AppsFlyer — the MMP and system of record. The dev key is per ACCOUNT,
    // not per app, so this is the same key HearHim uses; AllergyFit just has
    // to be added as an app in that AppsFlyer account (by Apple App ID).
    static let appsFlyerDevKey = "8P3KRaNmWiCLZgDJYFS867"

    // Meta — developers.facebook.com → create app → Settings → Basic.
    // The app must be in LIVE mode (not Development) before App Promotion
    // campaigns will accept it; that cost a full day on HearHim.
    static let metaAppID = ""
    static let metaClientToken = ""

    // TikTok — Events Manager → Web & App → app → Settings → App SDK.
    // `tiktokAccessToken` is the *App Secret* on that page. The SDK signs every
    // event with it; events signed with an empty/wrong secret are dropped
    // server-side without any error, which looks exactly like "no installs".
    static let tiktokAppID = ""
    static let tiktokAccessToken = ""

    static var appsFlyerEnabled: Bool { !appsFlyerDevKey.isEmpty }
    static var metaEnabled: Bool { !metaAppID.isEmpty && !metaClientToken.isEmpty }
    static var tiktokEnabled: Bool { !tiktokAppID.isEmpty && !tiktokAccessToken.isEmpty }
    static var anyNetworkEnabled: Bool { appsFlyerEnabled || metaEnabled || tiktokEnabled }
    /// Tracking (ATT + IDFA) is only meaningful once an ad network can use it.
    static var trackingEnabled: Bool { metaEnabled || tiktokEnabled }
}
