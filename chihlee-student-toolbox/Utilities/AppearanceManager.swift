import UIKit

/// Single source of truth for the app's colour scheme.
/// Sets UIKit's overrideUserInterfaceStyle on every connected window,
/// which automatically propagates through the trait collection to both
/// UIKit surfaces (UITabBar, UINavigationBar) and SwiftUI views.
enum AppearanceManager {

    static func uiStyle(for rawValue: String) -> UIUserInterfaceStyle {
        switch AppAppearance(rawValue: rawValue) ?? .system {
        case .system: return .unspecified
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    @MainActor
    static func apply(_ appearance: AppAppearance, animated: Bool = false) {
        let style = uiStyle(for: appearance.rawValue)
        for scene in UIApplication.shared.connectedScenes {
            guard let ws = scene as? UIWindowScene else { continue }
            // Window-level override is the single source of truth.
            // Setting `.unspecified` returns control to system appearance.
            ws.windows.forEach { window in
                guard animated else {
                    window.overrideUserInterfaceStyle = style
                    return
                }

                UIView.transition(
                    with: window,
                    duration: 0.28,
                    options: [.transitionCrossDissolve, .allowAnimatedContent]
                ) {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }
}
