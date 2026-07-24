import SwiftUI
import WebKit

struct RemoteMiniApp: Identifiable {
    let id: String
    let title: IlovalarView.Copy
    let subtitle: IlovalarView.Copy
    let imageKey: String
    let colors: [Color]
}

struct RemoteMiniAppView: View {
    let app: RemoteMiniApp
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode = "uz"

    var body: some View {
        NavigationStack {
            AuthenticatedMiniAppWebView(appID: app.id)
                .ignoresSafeArea(.container, edges: .bottom)
                .navigationTitle(app.title.pick(languageCode))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(SalomTheme.Colors.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(SalomTheme.Colors.surface)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(closeLabel)
                    }
                }
                .toolbarBackground(SalomTheme.Colors.bgMain, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var closeLabel: String {
        switch languageCode {
        case "ru": "Закрыть"
        case "en": "Close"
        case "kr", "uz-Cyrl": "Ёпиш"
        default: "Yopish"
        }
    }
}

private struct AuthenticatedMiniAppWebView: UIViewRepresentable {
    let appID: String
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode = "uz"
    @AppStorage(AppStorageKeys.preferredThemeMode) private var themeMode = "auto"

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // The access token belongs only to this in-app session. It is never put
        // in the URL and the website store is discarded with the sheet.
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: bootstrapScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        guard let url = URL(string: "https://salom-ai.uz/apps/\(appID)?embed=ios") else {
            return webView
        }
        webView.load(URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    private var bootstrapScript: String {
        let webLanguage: String
        switch languageCode {
        case "uz-Cyrl", "kr": webLanguage = "kr"
        case "ru": webLanguage = "ru"
        case "en": webLanguage = "en"
        default: webLanguage = "uz"
        }

        let values = [
            "access_token": TokenStore.shared.accessToken ?? "",
            "salom-lang": webLanguage,
            "salom-theme": ["light", "dark", "auto"].contains(themeMode) ? themeMode : "auto",
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: values),
              let json = String(data: data, encoding: .utf8) else {
            return ""
        }
        return """
        (() => {
          const values = \(json);
          Object.entries(values).forEach(([key, value]) => {
            if (value) window.localStorage.setItem(key, value);
          });
          window.__SALOM_EMBEDDED_IOS__ = true;
        })();
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            let host = url.host?.lowercased()
            let trustedHost = host == "salom-ai.uz" || host?.hasSuffix(".salom-ai.uz") == true
            if trustedHost {
                decisionHandler(.allow)
            } else if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                decisionHandler(.cancel)
                DispatchQueue.main.async { UIApplication.shared.open(url) }
            } else {
                decisionHandler(.cancel)
            }
        }
    }
}
