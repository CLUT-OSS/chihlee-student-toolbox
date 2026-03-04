import SwiftUI

struct ColorHelper {
    /// Default course colors
    static let courseColors: [(name: String, hex: String)] = [
        ("藍色", "#007AFF"),
        ("紅色", "#FF3B30"),
        ("綠色", "#34C759"),
        ("橘色", "#FF9500"),
        ("紫色", "#AF52DE"),
        ("粉紅", "#FF2D55"),
        ("靛藍", "#5856D6"),
        ("青色", "#00C7BE"),
    ]

    /// Convert hex string to Color
    static func color(from hex: String) -> Color {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        guard hexString.count == 6,
              let rgb = UInt64(hexString, radix: 16)
        else { return .blue }

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        return Color(red: r, green: g, blue: b)
    }
}
