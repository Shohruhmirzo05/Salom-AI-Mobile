//
//  PersonaStore.swift
//  Salom-Ai-iOS
//
//  Onboarding persona is collected BEFORE login, so we save it locally and push
//  it to the backend (POST /account/persona) once the user is authenticated.
//

import Foundation

enum PersonaStore {
    static let schemaVersion = 2
    private static let roleKey = "persona_role"
    private static let goalsKey = "persona_goals"
    private static let pendingKey = "persona_pending_sync"
    private static let completedVersionKey = "persona_completed_version"

    static var role: String? { UserDefaults.standard.string(forKey: roleKey) }
    static var goals: [String] { UserDefaults.standard.stringArray(forKey: goalsKey) ?? [] }
    static var isCompleted: Bool {
        role != nil && UserDefaults.standard.integer(forKey: completedVersionKey) >= schemaVersion
    }

    /// Save answers locally (during onboarding, pre-auth) and mark for sync.
    static func saveLocal(role: String?, goals: [String]) {
        let d = UserDefaults.standard
        guard let role, !role.isEmpty else { return }
        d.set(role, forKey: roleKey)
        d.set(goals, forKey: goalsKey)
        d.set(schemaVersion, forKey: completedVersionKey)
        d.set(true, forKey: pendingKey)
    }

    /// Push a pending persona to the backend once logged in. Safe to call on every
    /// launch / foreground — no-ops unless there's something to sync and a token.
    static func syncIfPending() {
        let d = UserDefaults.standard
        guard d.bool(forKey: pendingKey) else { return }
        guard TokenStore.shared.accessToken != nil else { return }
        let role = d.string(forKey: roleKey)
        let goals = d.stringArray(forKey: goalsKey) ?? []
        guard role != nil || !goals.isEmpty else { d.set(false, forKey: pendingKey); return }
        Task {
            do {
                _ = try await APIClient.shared.requestData(.savePersona(role: role, goals: goals))
                d.set(false, forKey: pendingKey)
                Analytics.shared.trackOnce("persona_saved", ["role": role ?? "skip", "goals": goals.count])
            } catch {
                // Leave the pending flag set — retry on next launch.
                print("⚠️ persona sync failed: \(error)")
            }
        }
    }
}
