import Foundation
import UIKit
import AppTrackingTransparency
#if canImport(AppsFlyerLib)
import AppsFlyerLib
#endif
#if canImport(FBSDKCoreKit)
import FBSDKCoreKit
#endif
#if canImport(TikTokBusinessSDK)
import TikTokBusinessSDK
#endif
#if canImport(RevenueCat)
import RevenueCat
#endif

/// Ad attribution and conversion events across AppsFlyer, Meta and TikTok.
///
/// Two things learned the hard way on HearHim, both of which this file
/// exists to prevent:
///
/// 1. Every network needs its own SDK in the binary to see anything. TikTok's
///    SDK was shipped and Meta's wasn't, so Meta reported zero installs for
///    months and its algorithm — with no feedback — chased nothing.
/// 2. Installs alone teach the networks to find people who tap "Get". They
///    optimise on whatever event you send, so send the events that mean
///    money: paywall viewed → trial started → purchase.
///
/// Everything is wrapped in `#if canImport` so the project still builds if a
/// package hasn't resolved, and skipped on the simulator, where none of the
/// SDKs have anything useful to report.
enum AdAttribution {

    // MARK: Lifecycle

    /// Configure every SDK once, at launch, before anything is logged.
    static func configure() {
        #if !targetEnvironment(simulator)
        #if canImport(AppsFlyerLib)
        if AdConfig.appsFlyerEnabled {
            let af = AppsFlyerLib.shared()
            af.appsFlyerDevKey = AdConfig.appsFlyerDevKey
            af.appleAppID = AdConfig.appleAppID
            // Hold the first launch report until the user has answered ATT,
            // so the IDFA (if granted) is on the install. Our ATT prompt comes
            // at the end of onboarding, so allow enough time to get there.
            af.waitForATTUserAuthorization(timeoutInterval: 90)
        }
        #endif

        #if canImport(FBSDKCoreKit)
        if AdConfig.metaEnabled {
            Settings.shared.appID = AdConfig.metaAppID
            Settings.shared.clientToken = AdConfig.metaClientToken
            Settings.shared.displayName = "SafeFuel"
            Settings.shared.isAutoLogAppEventsEnabled = true
            // Off until ATT is granted — see applyTrackingAuthorization.
            Settings.shared.isAdvertiserIDCollectionEnabled = false
            ApplicationDelegate.shared.application(
                UIApplication.shared, didFinishLaunchingWithOptions: nil)
        }
        #endif

        #if canImport(TikTokBusinessSDK)
        if AdConfig.tiktokEnabled,
           let config = TikTokConfig(accessToken: AdConfig.tiktokAccessToken,
                                     appId: AdConfig.appleAppID,
                                     tiktokAppId: AdConfig.tiktokAppID) {
            config.disableTracking()               // until ATT is granted
            #if DEBUG
            config.enableDebugMode()
            config.setLogLevel(TikTokLogLevelDebug)
            #endif
            TikTokBusiness.initializeSdk(config) { ok, error in
                if let error { print("[TikTok] init failed: \(error)") }
                else { print("[TikTok] init: \(ok)") }
            }
        }
        #endif
        #endif
    }

    /// Call each time the app becomes active.
    static func start() {
        #if !targetEnvironment(simulator)
        #if canImport(AppsFlyerLib)
        if AdConfig.appsFlyerEnabled {
            AppsFlyerLib.shared().start()
            #if canImport(RevenueCat)
            // Lets RevenueCat forward purchase + RENEWAL events to AppsFlyer
            // server-side (client events only see the first purchase).
            // Turned on in RevenueCat → Integrations → AppsFlyer.
            Purchases.shared.attribution.setAppsflyerID(AppsFlyerLib.shared().getAppsFlyerUID())
            #endif
        }
        #endif
        #if canImport(FBSDKCoreKit)
        if AdConfig.metaEnabled {
            // One "activation" per foreground; this is what lights the app up
            // in Meta Events Manager and feeds its session metrics.
            AppEvents.shared.activateApp()
            #if canImport(RevenueCat)
            Purchases.shared.attribution.setFBAnonymousID(AppEvents.shared.anonymousID)
            #endif
        }
        #endif
        #endif
    }

    // MARK: Conversion events

    /// The paywall was shown. `source` names the surface that opened it so the
    /// funnel can be read per touchpoint ("onboarding", "profile", "recipes").
    static func logPaywallView(source: String) {
        #if !targetEnvironment(simulator)
        #if canImport(AppsFlyerLib)
        if AdConfig.appsFlyerEnabled {
            AppsFlyerLib.shared().logEvent(AFEventContentView,
                                           withValues: [AFEventParamContentType: "paywall",
                                                        AFEventParamContent: source])
        }
        #endif
        #if canImport(FBSDKCoreKit)
        if AdConfig.metaEnabled {
            AppEvents.shared.logEvent(.viewedContent,
                                      parameters: [AppEvents.ParameterName("fb_content_type"): "paywall",
                                                   AppEvents.ParameterName("fb_content"): source])
        }
        #endif
        #if canImport(TikTokBusinessSDK)
        if AdConfig.tiktokEnabled {
            let e = TikTokBaseEvent(eventName: "ViewContent")
            e.addProperty(withKey: "content_type", value: "paywall")
            e.addProperty(withKey: "content_id", value: source)
            TikTokBusiness.trackTTEvent(e)
        }
        #endif
        #endif
    }

    /// A free trial started. Kept separate from `logPurchase` because a trial is
    /// worth $0 today and the networks would otherwise learn to chase people
    /// who never convert — but it's the earliest signal that an install was
    /// a real person who wanted the product.
    static func logTrialStart(productID: String) {
        #if !targetEnvironment(simulator)
        #if canImport(AppsFlyerLib)
        if AdConfig.appsFlyerEnabled {
            AppsFlyerLib.shared().logEvent(AFEventStartTrial,
                                           withValues: [AFEventParamContentId: productID])
        }
        #endif
        #if canImport(FBSDKCoreKit)
        if AdConfig.metaEnabled {
            AppEvents.shared.logEvent(.startTrial,
                                      parameters: [AppEvents.ParameterName("fb_content_id"): productID])
        }
        #endif
        #if canImport(TikTokBusinessSDK)
        if AdConfig.tiktokEnabled {
            let e = TikTokBaseEvent(eventName: "StartTrial")
            e.addProperty(withKey: "content_id", value: productID)
            TikTokBusiness.trackTTEvent(e)
        }
        #endif
        #endif
    }

    /// Money actually moved. This is the event the ad platforms optimise on.
    /// - amount: what was charged, in `currency` (ISO 4217, per storefront).
    static func logPurchase(amount: Double, currency: String, productID: String) {
        #if !targetEnvironment(simulator)
        #if canImport(AppsFlyerLib)
        if AdConfig.appsFlyerEnabled {
            AppsFlyerLib.shared().logEvent(AFEventPurchase, withValues: [
                AFEventParamRevenue: amount,
                AFEventParamCurrency: currency,
                AFEventParamContentId: productID,
            ])
        }
        #endif
        #if canImport(FBSDKCoreKit)
        if AdConfig.metaEnabled {
            // The dedicated revenue call — distinct from a named event, and the
            // one Meta's value optimisation reads.
            AppEvents.shared.logPurchase(amount: amount, currency: currency,
                                         parameters: [AppEvents.ParameterName("fb_content_id"): productID])
        }
        #endif
        #if canImport(TikTokBusinessSDK)
        if AdConfig.tiktokEnabled {
            let e = TikTokPurchaseEvent(eventName: "Purchase")
            e.setValue(NSNumber(value: amount), forKey: "value")
            e.setValue(currency, forKey: "currency")
            e.setValue(productID, forKey: "content_id")
            TikTokBusiness.trackTTEvent(e)
        }
        #endif
        #endif
    }

    /// The activation event: onboarding finished and the profile is written.
    /// Cheap, early, and fires for far more people than a purchase — so it's
    /// what the networks optimise on until purchase volume is meaningful.
    static func logOnboardingComplete() {
        #if !targetEnvironment(simulator)
        #if canImport(AppsFlyerLib)
        if AdConfig.appsFlyerEnabled {
            AppsFlyerLib.shared().logEvent(AFEventCompleteRegistration, withValues: nil)
        }
        #endif
        #if canImport(FBSDKCoreKit)
        if AdConfig.metaEnabled { AppEvents.shared.logEvent(.completedRegistration) }
        #endif
        #if canImport(TikTokBusinessSDK)
        if AdConfig.tiktokEnabled {
            TikTokBusiness.trackTTEvent(TikTokBaseEvent(eventName: "CompleteRegistration"))
        }
        #endif
        #endif
    }

    // MARK: App Tracking Transparency

    /// Ask once, after the first value moment (the "Your plan is ready" step)
    /// and never on top of the paywall. No-op when no network can use it, and
    /// when the user has already answered.
    @MainActor
    static func requestTrackingIfNeeded() async {
        guard AdConfig.trackingEnabled else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            applyTrackingAuthorization()
            return
        }
        _ = await ATTrackingManager.requestTrackingAuthorization()
        applyTrackingAuthorization()
    }

    private static func applyTrackingAuthorization() {
        let granted = ATTrackingManager.trackingAuthorizationStatus == .authorized
        #if !targetEnvironment(simulator)
        #if canImport(FBSDKCoreKit)
        if AdConfig.metaEnabled { Settings.shared.isAdvertiserIDCollectionEnabled = granted }
        #endif
        #if canImport(TikTokBusinessSDK)
        if AdConfig.tiktokEnabled { TikTokBusiness.setTrackingEnabled(granted) }
        #endif
        #endif
    }
}
