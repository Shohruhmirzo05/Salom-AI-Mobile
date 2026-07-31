//
//  Salom_Ai_iOSApp.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 11/11/25.
//

import SwiftUI
import Combine
import OneSignalFramework
import GoogleMobileAds
import AppTrackingTransparency

@main
struct Salom_Ai_iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage(AppStorageKeys.preferredLanguageCode) var languageCode: String = "uz"
    @AppStorage(AppStorageKeys.preferredThemeMode) private var themeModeRaw: String = AppThemeMode.auto.rawValue
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var session = SessionManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .environment(\.locale, Locale(identifier: languageCode))
                .preferredColorScheme(AppThemeMode(rawValue: themeModeRaw)?.preferredColorScheme)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // OAuth also moves the app through inactive/background.
                        // Payment recovery belongs only to an authenticated main
                        // session, never to login or onboarding callbacks.
                        if session.contentType == .main,
                           TokenStore.shared.accessToken != nil {
                            Task {
                                // Refresh on every foreground. Doubles as the fallback for
                                // when the user returns from Safari via the back button and
                                // the salomai:// deep link never fired — a confirmed upgrade
                                // still surfaces the success toast exactly once.
                                await SubscriptionManager.shared.refreshAfterForeground()
                            }
                        }
                        // Register OneSignal push id with backend so notifications deliver.
                        PushManager.syncDevice()
                    }
                }
                .onOpenURL { url in
                    // Deep link from the web payment-result page after Payme/Click:
                    //   salomai://payment/result?payment_id=...&status=paid
                    // Brings the user straight back into the app, refreshes their plan,
                    // and shows the result toast based on the trusted `status` param.
                    if url.scheme == "salomai", url.host == "payment" || url.path.contains("payment") {
                        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                        let status = items?.first(where: { $0.name == "status" })?.value
                        let paymentId = items?.first(where: { $0.name == "payment_id" })?.value.flatMap(Int.init)
                        Task { await SubscriptionManager.shared.handlePaymentReturn(status: status, paymentId: paymentId) }
                    } else {
                        AppDeepLinkRouter.shared.open(url)
                    }
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

       // Enable verbose logging for debugging (remove in production)
       OneSignal.Debug.setLogLevel(.LL_VERBOSE)
       // Initialize with your OneSignal App ID
       OneSignal.initialize("4bf70eb4-54f5-4479-8ef4-70e262dc6d2b", withLaunchOptions: launchOptions)
       // Permission is requested contextually after the user has completed
       // several useful tasks; never interrupt first launch or authentication.

       // Google Mobile Ads is deliberately NOT initialized here. It is started
       // by TrackingAuthorizationManager only after ATT has been resolved.
       // This guarantees that no ad request can access IDFA before the user has
       // made their choice.

       return true
    }
}

/// Owns the one-time ATT gate and the dependent Google Mobile Ads startup.
///
/// ATT is part of the first-run setup in `ContentView`. Existing users who
/// completed onboarding on an older build still see the privacy step whenever
/// their system status remains `.notDetermined`.
@MainActor
final class TrackingAuthorizationManager: ObservableObject {
    static let shared = TrackingAuthorizationManager()

    @Published private(set) var status: ATTrackingManager.AuthorizationStatus
    @Published private(set) var isRequesting = false

    private var didStartMobileAds = false

    private init() {
        status = ATTrackingManager.trackingAuthorizationStatus
    }

    var needsOnboardingStep: Bool {
        status == .notDetermined
    }

    /// Call on launch so returning users with an existing ATT decision can
    /// initialize ads without seeing the onboarding step again.
    func startAdsIfAuthorizationResolved() {
        status = ATTrackingManager.trackingAuthorizationStatus
        guard status != .notDetermined else { return }
        startMobileAdsOnce()
    }

    /// Called only from a clear user action on the privacy onboarding screen.
    /// The system prompt is the sole place where the user grants or denies.
    func requestAuthorization() {
        guard !isRequesting else { return }

        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        guard currentStatus == .notDetermined else {
            status = currentStatus
            startMobileAdsOnce()
            return
        }

        isRequesting = true
        ATTrackingManager.requestTrackingAuthorization { newStatus in
            Task { @MainActor in
                TrackingAuthorizationManager.shared.finishAuthorization(with: newStatus)
            }
        }
    }

    private func finishAuthorization(with newStatus: ATTrackingManager.AuthorizationStatus) {
        status = newStatus
        isRequesting = false
        startMobileAdsOnce()
    }

    private func startMobileAdsOnce() {
        guard !didStartMobileAds else { return }
        didStartMobileAds = true

        MobileAds.shared.start { _ in
            Task { @MainActor in
                let unitID = await RewardedAdManager.fetchRewardedUnitID()
                RewardedAdManager.shared.configure(unitID: unitID)
            }
        }
    }
}
/*
 
 so i checked the ios app, the 
 
 
 */
