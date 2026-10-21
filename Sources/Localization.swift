import Foundation

enum AppLanguage: String, Codable, CaseIterable {
    case system = "system"
    case english = "en"
    case spanish = "es"
}

enum L10n {
    static var isSpanish: Bool {
        switch AppSettings.shared.appLanguage {
        case .english:
            return false
        case .spanish:
            return true
        case .system:
            guard let preferred = Locale.preferredLanguages.first?.lowercased() else {
                return false
            }
            return preferred.hasPrefix("es")
        }
    }

    static func tr(_ en: String, _ es: String) -> String {
        return isSpanish ? es : en
    }
}
