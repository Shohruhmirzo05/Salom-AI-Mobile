//
//  PushManager.swift
//  Salom-Ai-iOS
//
//  Registers this device's OneSignal push id with the backend. Without this the
//  server has no iOS token and can never deliver notifications — which is why
//  iOS push wasn't working. Safe to call repeatedly (on login + on foreground).
//

import Foundation
import OneSignalFramework

enum PushManager {
    private static let successfulTasksKey = "push_successful_tasks"
    private static let permissionAskedKey = "push_permission_asked_after_value"

    /// Ask only after repeated value, never during first launch/auth. The system
    /// prompt is still the source of truth and is shown at most once by us.
    static func recordSuccessfulTask() {
        guard TokenStore.shared.accessToken != nil else { return }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: permissionAskedKey) else { return }
        let count = defaults.integer(forKey: successfulTasksKey) + 1
        defaults.set(count, forKey: successfulTasksKey)
        guard count >= 3 else { return }
        defaults.set(true, forKey: permissionAskedKey)
        OneSignal.Notifications.requestPermission({ accepted in
            if accepted { syncDevice() }
        }, fallbackToSettings: false)
    }

    static func syncDevice() {
        guard TokenStore.shared.accessToken != nil else { return }
        Task {
            // The OneSignal subscription id can be nil right after launch/login,
            // so retry a few times with backoff until it's available.
            for attempt in 0..<6 {
                if let id = OneSignal.User.pushSubscription.id, !id.isEmpty {
                    do {
                        _ = try await APIClient.shared.requestData(.registerPushDevice(token: id, platform: "ios"))
                        print("✅ Push device registered with backend: \(id)")
                    } catch {
                        print("⚠️ Push device registration failed: \(error)")
                    }
                    return
                }
                try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 1_500_000_000)
            }
            print("⚠️ Push subscription id never became available")
        }
    }
}
