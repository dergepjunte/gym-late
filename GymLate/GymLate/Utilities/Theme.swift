import SwiftUI

/// Central home for gradients, type and surface tokens.
/// v0.3 "Iron" design: graphite steel, safety-yellow, condensed poster type.
enum Theme {
    // MARK: - Story-slide gradients (Recap / Wrapped) — darker, harder, gym-poster colours

    static let slideTitle:   [Color] = [Color(hex: "#b88a00"), Color(hex: "#1a1300")]
    static let slideLate:    [Color] = [Color(hex: "#ff453a"), Color(hex: "#8f1d17")]
    static let slideMinutes: [Color] = [Color(hex: "#2a2a2e"), Color(hex: "#0a0a0b")]
    static let slideKing:    [Color] = [Color(hex: "#9c7300"), Color(hex: "#140f00")]
    static let slideSkip:    [Color] = [Color(hex: "#3a3a40"), Color(hex: "#141416")]
    static let slideCTA:     [Color] = [Color(hex: "#8a6400"), Color(hex: "#0a0a0b")]
    static let slideRanking: [Color] = [Color(hex: "#1d1d20"), Color(hex: "#000000")]
    static let slides: [[Color]] = [slideTitle, slideLate, slideMinutes, slideKing, slideSkip, slideRanking]

    static let hype: [Color] = [Color(hex: "#ffd60a"), Color(hex: "#f5b400")]
    static let accentGradient: [Color] = [K.accentLight, K.accent, K.accentDeep]

    // MARK: - Typography ("gym poster" type system)
    //
    // display = condensed black italic numbers/headlines (like plate stencils and
    // gym-wall posters), heading = condensed heavy, body = plain SF (sharp, not rounded).

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.compressed).italic()
    }
    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.condensed)
    }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight)
    }
    /// Scoreboard digits: monospaced, condensed, heavy.
    static func score(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.condensed).monospacedDigit()
    }

    /// Big numbers: hot yellow, deepening at the bottom like a lit plate.
    static func numberGradient(for scheme: ColorScheme) -> [Color] {
        [K.accentLight, K.accent, K.accentDeep]
    }

    // MARK: - Steel surface tokens

    struct Glass {
        let sheen: Color
        let borderTop: Color
        let border: Color
        let shadow: Color

        static func tokens(for scheme: ColorScheme) -> Glass {
            Glass(sheen: .white.opacity(0.06),
                  borderTop: .white.opacity(0.16),
                  border: .white.opacity(0.06),
                  shadow: .black.opacity(0.6))
        }
    }
}

extension Text {
    /// Gym-wall micro-label: a yellow tape tick + condensed uppercase, tracked out.
    func eyebrow(_ color: Color = K.amberText) -> some View {
        HStack(spacing: 7) {
            Rectangle().fill(color).frame(width: 3, height: 12)
                .rotationEffect(.degrees(12))
            self
                .font(.system(size: 12, weight: .heavy).width(.condensed))
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundColor(color)
        }
    }
}
