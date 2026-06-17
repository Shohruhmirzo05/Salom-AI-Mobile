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
