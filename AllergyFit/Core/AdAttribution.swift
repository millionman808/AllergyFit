import UIKit
import Foundation
import AppTrackingTransparency
import AdSupport
import FacebookCore
import TikTokBusinessSDK

/// Install-attribution SDKs for paid acquisition (Meta + TikTok).
///
/// Both stay COMPLETELY INERT until their IDs are filled in below — no SDK is
/// started, no identifier is read and no event is sent while the placeholders
/// are empty. That means shipping this build without advertising collects
/// nothing, and the App Privacy answers only change once you switch it on.
enum AdAttribution {

    // MARK: Configuration — fill these in when you're ready to run ads.

    /// Meta app ID from developers.facebook.com (leave empty to stay off).
    static let metaAppID = ""
    static let metaClientToken = ""

    /// TikTok Events app ID + token from TikTok Ads Manager (leave empty to stay off).
    static let tiktokAppID = ""
    static let tiktokTTAppID = ""

    static var metaEnabled: Bool { !metaAppID.isEmpty && !metaClientToken.isEmpty }
    static var tiktokEnabled: Bool { !tiktokAppID.isEmpty && !tiktokTTAppID.isEmpty }
    static var anyEnabled: Bool { metaEnabled || tiktokEnabled }

    // MARK: Lifecycle

    /// Call from app launch. No-op unless an ID is configured.
    static func start(launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        guard anyEnabled else { return }

        if metaEnabled {
            Settings.shared.appID = metaAppID
            Settings.shared.clientToken = metaClientToken
            // Don't collect the advertiser ID until (and unless) ATT is granted.
            Settings.shared.isAdvertiserIDCollectionEnabled = false
            Settings.shared.isAutoLogAppEventsEnabled = true
            ApplicationDelegate.shared.application(
                UIApplication.shared, didFinishLaunchingWithOptions: launchOptions)
        }

        if tiktokEnabled {
            let config = TikTokConfig(appId: tiktokAppID, tiktokAppId: tiktokTTAppID)
            config?.disableTracking()          // stays off until ATT is granted
            TikTokBusiness.initializeSdk(config)
        }
    }

    /// Ask for tracking permission, then enable ad-identifier collection only if
    /// the user actually said yes. Call after onboarding — never on first launch,
    /// where the prompt has no context and gets denied.
    static func requestTrackingIfNeeded() async {
        guard anyEnabled else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            applyAuthorization()
            return
        }
        _ = await ATTrackingManager.requestTrackingAuthorization()
        applyAuthorization()
    }

    private static func applyAuthorization() {
        let granted = ATTrackingManager.trackingAuthorizationStatus == .authorized
        if metaEnabled {
            Settings.shared.isAdvertiserIDCollectionEnabled = granted
        }
        if tiktokEnabled {
            TikTokBusiness.setTrackingEnabled(granted)
        }
    }

    // MARK: Events worth optimising campaigns against

    static func logCompletedOnboarding() {
        guard anyEnabled else { return }
        if metaEnabled { AppEvents.shared.logEvent(.completedRegistration) }
        if tiktokEnabled { TikTokBusiness.trackEvent("CompleteRegistration") }
    }

    static func logStartedTrial() {
        guard anyEnabled else { return }
        if metaEnabled { AppEvents.shared.logEvent(.startTrial) }
        if tiktokEnabled { TikTokBusiness.trackEvent("StartTrial") }
    }

    static func logSubscribed(value: Double, currency: String) {
        guard anyEnabled else { return }
        if metaEnabled {
            AppEvents.shared.logPurchase(amount: value, currency: currency)
        }
        if tiktokEnabled { TikTokBusiness.trackEvent("Subscribe") }
    }
}
