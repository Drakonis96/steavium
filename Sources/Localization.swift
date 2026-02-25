import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .english:
            return "English"
        case .spanish:
            return "Espanol"
        }
    }

    func pick(_ english: String, _ spanish: String) -> String {
        self == .spanish ? spanish : english
    }
}
