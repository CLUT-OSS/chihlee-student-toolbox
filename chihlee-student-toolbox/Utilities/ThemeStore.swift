import Foundation
import Observation

@MainActor
@Observable
final class ThemeStore {
    private enum Keys {
        static let appearanceMode = "appearanceMode"
        static let legacyDarkMode = "isDarkMode"
    }

    var appearance: AppAppearance {
        didSet {
            guard appearance != oldValue else { return }
            defaults.set(appearance.rawValue, forKey: Keys.appearanceMode)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.appearance = Self.initialAppearance(from: defaults)
        defaults.set(appearance.rawValue, forKey: Keys.appearanceMode)
    }

    private static func initialAppearance(from defaults: UserDefaults) -> AppAppearance {
        if let rawValue = defaults.string(forKey: Keys.appearanceMode),
           let appearance = AppAppearance(rawValue: rawValue) {
            return appearance
        }

        if defaults.object(forKey: Keys.legacyDarkMode) != nil,
           defaults.bool(forKey: Keys.legacyDarkMode) {
            return .dark
        }

        return .system
    }
}
