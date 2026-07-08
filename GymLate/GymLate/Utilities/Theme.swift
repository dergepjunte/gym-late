import SwiftUI

/// Central home for multi-color gradients and Liquid Glass surface tokens.
enum Theme {
    // MARK: - Story-slide gradients (Recap / Wrapped)

    static let slideTitle:   [Color] = [Color(hex: "#f59e0b"), Color(hex: "#ea580c")]
    static let slideLate:    [Color] = [Color(hex: "#db2777"), Color(hex: "#ea580c")]
    static let slideMinutes: [Color] = [Color(hex: "#059669"), Color(hex: "#0891b2")]
    static let slideKing:    [Color] = [Color(hex: "#ca8a04"), Color(hex: "#dc2626")]
    static let slideCTA:     [Color] = [Color(hex: "#78350f"), Color(hex: "#b45309")]
    static let slides: [[Color]] = [slideTitle, slideLate, slideMinutes, slideKing]

    static let hype: [Color] = [Color(hex: "#f59e0b"), Color(hex: "#ea580c")]
    static let accentGradient: [Color] = [K.accent, K.accentDeep]

    // MARK: - Glass surface tokens (mirrors the web app's --glass-* variables)

    struct Glass {
        let sheen: Color
        let borderTop: Color
        let border: Color
        let shadow: Color

        static func tokens(for scheme: ColorScheme) -> Glass {
            scheme == .dark
            ? Glass(sheen: .white.opacity(0.09),
                    borderTop: .white.opacity(0.22),
                    border: .white.opacity(0.11),
                    shadow: .black.opacity(0.50))
            : Glass(sheen: .white.opacity(0.45),
                    borderTop: .white.opacity(0.85),
                    border: .white.opacity(0.55),
                    shadow: Color(hex: "#a06e14").opacity(0.10))
        }
    }
}
