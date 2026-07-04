import Foundation
internal import UIKit
import Combine

/// Lightweight product-analytics client — mirrors the web (`track`) and the
/// Telegram bot. Batches interaction events and POSTs them to `/events` (the
/// same endpoint that feeds the admin Insights funnel). Fire-and-forget: it
/// never throws into the app and never blocks the UI.
///
/// Usage:  Analytics.shared.track("paywall_shown")
///         Analytics.shared.track("paywall_plan_clicked", ["plan": code])
final class Analytics {
    static let shared = Analytics()

    private struct Event { let name: String; let props: [String: Any]? }
    private var queue: [Event] = []
    private let lock = NSLock()
    private var timer: Timer?

    private init() {
        // Periodic flush.
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.flush()
            }
        }
        // Flush when the app goes to the background so we don't lose events.
        NotificationCenter.default.addObserver(
            self, selector: #selector(flushNow),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
    }

    private var sessionId: String {
        let key = "salom_analytics_sid"
        if let s = UserDefaults.standard.string(forKey: key) { return s }
        let s = UUID().uuidString
        UserDefaults.standard.set(s, forKey: key)
        return s
    }

    /// Device/app version reported with each batch → admin version breakdown.
    private var deviceInfo: (os: String, app: String, model: String) {
        let os = UIDevice.current.systemVersion  // e.g. "17.5.1"
        let app = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        var sys = utsname()
        uname(&sys)
        let model = withUnsafePointer(to: &sys.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(validatingUTF8: $0) }
        } ?? "?"  // e.g. "iPhone15,3"
        return (os, app, model)
    }

    /// Record an interaction. Safe to call from anywhere, on any thread.
    func track(_ name: String, _ props: [String: Any]? = nil) {
        lock.lock()
        queue.append(Event(name: name, props: props))
        let count = queue.count
        lock.unlock()
        if count >= 12 { flush() }
    }

    @objc private func flushNow() { flush() }

    func flush() {
        lock.lock()
        let batch = queue
        queue.removeAll()
        lock.unlock()
        guard !batch.isEmpty else { return }

        let eventsJSON: [[String: Any]] = batch.map { e in
            var d: [String: Any] = ["name": e.name, "platform": "ios"]
            if let p = e.props { d["props"] = p }
            return d
        }
        let dev = deviceInfo
        let body: [String: Any] = [
            "events": eventsJSON, "platform": "ios", "session_id": sessionId,
            "os_version": dev.os, "app_version": dev.app, "device_model": dev.model
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }

        let url = APIClient.shared.baseURL.appendingPathComponent("events")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = TokenStore.shared.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = data
        URLSession.shared.dataTask(with: req).resume()  // fire-and-forget
    }
}
