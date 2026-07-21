import SwiftUI
internal import UIKit

extension String {
    /// Resolves dynamic strings with the language selected inside Salom AI.
    /// `String(localized:)` otherwise follows the device language and can mix
    /// English with an in-app Russian or Uzbek selection.
    static func appLocalized(_ key: String) -> String {
        let languageCode = UserDefaults.standard.string(forKey: AppStorageKeys.preferredLanguageCode) ?? "uz"
        let baseLanguageCode = Locale(identifier: languageCode).language.languageCode?.identifier
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj")
                ?? baseLanguageCode.flatMap({ Bundle.main.path(forResource: $0, ofType: "lproj") }),
              let bundle = Bundle(path: path) else {
            return key
        }
        return NSLocalizedString(key, tableName: "Localizable", bundle: bundle, comment: "")
    }
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .auto: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .auto: "Avto"
        case .light: "Yorug‘"
        case .dark: "Tungi"
        }
    }

    var systemImage: String {
        switch self {
        case .auto: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

enum SalomTheme {
    enum Colors {
        static let bgMain = adaptive(light: "#F8F5EF", dark: "#050617")
        static let bgSecondary = adaptive(light: "#F0ECE4", dark: "#080A1F")
        static let surface = adaptive(light: "#FFFFFF", dark: "#111526")
        static let surfaceMuted = adaptive(light: "#F1EDE6", dark: "#171B30")
        static let surfaceElevated = adaptive(light: "#FFFFFF", dark: "#151A30")
        static let controlFill = adaptive(light: "#F4F1EB", dark: "#0E1224")
        static let controlFillActive = adaptive(light: "#E7F2FA", dark: "#182A40")
        static let border = adaptive(light: "#DCD5CA", dark: "#1AFFFFFF")
        static let separator = adaptive(light: "#E4DED5", dark: "#14FFFFFF")

        static let accentPrimary = adaptive(light: "#4C9FDC", dark: "#55B7E9")
        static let accentSecondary = adaptive(light: "#247ABD", dark: "#7BC8EE")
        static let accentTertiary = adaptive(light: "#326FB7", dark: "#4B87FF")
        static let signal = adaptive(light: "#C7F34F", dark: "#55B7E9")

        static let textPrimary = adaptive(light: "#11172A", dark: "#FFFFFF")
        static let textSecondary = adaptive(light: "#646978", dark: "#B8FFFFFF")
        static let textTertiary = adaptive(light: "#858A96", dark: "#73FFFFFF")
        // Text and icons placed on branded blue/gradient controls stay white in
        // every appearance. This prevents light mode from turning CTA labels dark.
        static let onAccent = Color.white
        static let onMedia = Color.white
        static let codeBackground = adaptive(light: "#F3F5F8", dark: "#090C17")
        static let codeHeader = adaptive(light: "#E7EBF0", dark: "#16FFFFFF")
        static let codeText = adaptive(light: "#172033", dark: "#EAF0FF")
        static let scrim = Color.black.opacity(0.46)
        static let danger = adaptive(light: "#C43B43", dark: "#F97373")
        static let success = adaptive(light: "#167A5B", dark: "#34D399")
        static let warning = adaptive(light: "#9A6500", dark: "#FBBF24")

        private static func adaptive(light: String, dark: String) -> Color {
            Color(uiColor: UIColor { traits in
                UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
            })
        }
    }

    enum Gradients {
        static let background = LinearGradient(
            colors: [Colors.bgMain, Colors.bgSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accent = LinearGradient(
            colors: [Colors.accentPrimary, Colors.accentTertiary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
