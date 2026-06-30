//
//  Salom_Ai_iOSApp.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 11/11/25.
//

import SwiftUI
import OneSignalFramework
import GoogleMobileAds

@main
struct Salom_Ai_iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage(AppStorageKeys.preferredLanguageCode) var languageCode: String = "uz"
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var session = SessionManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .environment(\.locale, Locale(identifier: languageCode))
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            // Check subscription whenever app comes to foreground
                            // This handles the case where user paid in Safari/Click app and returned
                            await SubscriptionManager.shared.checkSubscriptionStatus()
                        }
                        // Register OneSignal push id with backend so notifications deliver.
                        PushManager.syncDevice()
                    }
                }
                .onOpenURL { url in
                    // Deep link from the web payment-result page after Payme/Click:
                    //   salomai://payment/result?payment_id=...&status=paid
                    // Brings the user straight back into the app and refreshes their plan.
                    guard url.scheme == "salomai" else { return }
                    if url.host == "payment" || url.path.contains("payment") {
                        Task { await SubscriptionManager.shared.checkSubscriptionStatus() }
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
       // Use this method to prompt for push notifications.
       // We recommend removing this method after testing and instead use In-App Messages to prompt for notification permission.
       OneSignal.Notifications.requestPermission({ accepted in
         print("User accepted notifications: \(accepted)")
       }, fallbackToSettings: false)

       // Initialize Google Mobile Ads (rewarded ads → +1 message).
       MobileAds.shared.start { _ in
           Task { @MainActor in
               let unitID = await RewardedAdManager.fetchRewardedUnitID()
               RewardedAdManager.shared.configure(unitID: unitID)
           }
       }

       return true
    }
}
/*
 
 so i checked the ios app, the 
 
 
 */
