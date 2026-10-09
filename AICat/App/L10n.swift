import Foundation

/// Runtime localization that follows the language chosen inside the app (not only the system language).
///
/// Strings live in `AICat/Resources/Localizable.xcstrings` (generated from `Tools/strings_source.py`).
/// Xcode compiles the catalog into `<lang>.lproj/Localizable.strings`, so we can load the bundle
/// of the selected language directly. Every user-facing string in the app goes through `L10n`.
enum L10n {
    /// Supported in-app languages.
    enum Language: String, CaseIterable, Codable, Identifiable {
        case english = "en"
        case spanish = "es"

        var id: String { rawValue }

        /// Locale used for voices, number formatting and the Foundation Models session.
        var locale: Locale {
            switch self {
            case .english: return Locale(identifier: "en_US")
            case .spanish: return Locale(identifier: "es_MX")
            }
        }

        /// Best language for the current device settings.
        static var preferred: Language {
            let codes = Locale.preferredLanguages.map { $0.lowercased() }
            if let first = codes.first, first.hasPrefix("es") { return .spanish }
            return .english
        }
    }

    /// The language currently used for lookups. Set by `AppModel` when the player switches language.
    nonisolated(unsafe) static var current: Language = Language.preferred

    private nonisolated(unsafe) static var bundles: [Language: Bundle] = [:]

    private static func bundle(for language: Language) -> Bundle {
        if let cached = bundles[language] { return cached }
        let resolved: Bundle
        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            resolved = bundle
        } else {
            resolved = Bundle.main
        }
        bundles[language] = resolved
        return resolved
    }

    /// Localized string for `key` in the current in-app language. Falls back to the key itself.
    static func string(_ key: String) -> String {
        string(key, language: current)
    }

    static func string(_ key: String, language: Language) -> String {
        let value = bundle(for: language).localizedString(forKey: key, value: nil, table: "Localizable")
        if value == key, language != .english {
            return bundle(for: .english).localizedString(forKey: key, value: key, table: "Localizable")
        }
        return value
    }

    /// Localized format string with arguments (positional `%@` / `%d` / `%lld`).
    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), locale: current.locale, arguments: args)
    }
}
