import SwiftUI

/// Central home for multi-color gradients and Liquid Glass surface tokens.
enum Theme {
    // MARK: - Story-slide gradients (Recap / Wrapped)

    static let slideTitle:   [Color] = [Color(hex: "#f59e0b"), Color(hex: "#ea580c")]
    static let slideLate:    [Color] = [Color(hex: "#db2777"), Color(hex: "#ea580c")]
    static let slideMinutes: [Color] = [Color(hex: "#059669"), Color(hex: "#0891b2")]
    static let slideKing:    [Color] = [Color(hex: "#ca8a04"), Color(hex: "#dc2626")]
    static let slideSkip:    [Color] = [Color(hex: "#6366f1"), Color(hex: "#4338ca")]
    static let slideCTA:     [Color] = [Color(hex: "#78350f"), Color(hex: "#b45309")]
    static let slideRanking: [Color] = [Color(hex: "#b45309"), Color(hex: "#78350f")]
    static let slides: [[Color]] = [slideTitle, slideLate, slideMinutes, slideKing, slideSkip, slideRanking]

    static let hype: [Color] = [Color(hex: "#f59e0b"), Color(hex: "#ea580c")]
    static let accentGradient: [Color] = [K.accent, K.accentDeep]

    // MARK: - Typography ("scoreboard" type system)
    //
    // Three roles: display = big black rounded numbers (scoreboard),
    // heading = heavy rounded titles/names, body = rounded UI text.
    // Micro-labels use Text.eyebrow() below (expanded uppercase, jersey style).

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Adaptive amber gradient for big streak numbers — deeper in light mode
    /// for contrast, brighter in dark mode for glow.
    static func numberGradient(for scheme: ColorScheme) -> [Color] {
        scheme == .dark
        ? [K.accentLight, K.accentDeep]
        : [K.accentDeep, Color(hex: "#c2540a")]
    }

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

extension Text {
    /// Athletic uppercase micro-label (jersey style): expanded SF, heavy,
    /// tracked out, amber by default.
    func eyebrow(_ color: Color = K.amberText) -> some View {
        self
            .font(.system(size: 11, weight: .heavy).width(.expanded))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundColor(color)
    }
}
