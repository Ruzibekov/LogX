import Foundation

/// Oyna mavzusi: tizim bilan birga, doim qorong'i yoki doim yorug'.
public enum AppearancePreference: String, CaseIterable, Sendable {
    case system
    case dark
    case light

    public static let storageKey = "logx.appearance"

    public var title: String {
        switch self {
        case .system: return "Tizim bilan"
        case .dark: return "Qorong'i"
        case .light: return "Yorug'"
        }
    }

    public static func load(_ defaults: UserDefaults = .standard) -> AppearancePreference {
        guard let raw = defaults.string(forKey: storageKey),
              let value = AppearancePreference(rawValue: raw) else { return .dark }
        return value
    }

    public func save(_ defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: AppearancePreference.storageKey)
    }
}
