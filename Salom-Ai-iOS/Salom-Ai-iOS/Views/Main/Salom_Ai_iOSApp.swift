//
//  Salom_Ai_iOSApp.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 11/11/25.
//

import SwiftUI
import OneSignalFramework

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
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        Task {
                            // Check subscription whenever app comes to foreground
                            // This handles the case where user paid in Safari/Click app and returned
                            await SubscriptionManager.shared.checkSubscriptionStatus()
                        }
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

       return true
    }
}

// yandex
//Key ID
//ajeiiva400k3hjb6p6ej
//Your secret key
//AQVN0pfUQAKDjNZsmdNYahJzdPpSYNmZN5fTRwN6
