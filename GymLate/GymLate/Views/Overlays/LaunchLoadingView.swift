import SwiftUI

/// Cold-start loading screen shown while the first `refreshData()` call is
/// in flight (see AppState.isBootLoading). Sits on the same GymBackground
/// used by LandingView/AppRootView so the crossfade into the app is seamless.
///
/// The motif is user-selectable in Settings (LocalStore.loadingStyle);
/// barbell is the default, flame and wordmark are alternatives.
struct LaunchLoadingView: View {
    enum LoadingStyle: String, CaseIterable, Identifiable, Hashable {
        case barbell, flame, wordmark
        var id: String { rawValue }

        var label: String {
            switch self {
            case .barbell:  return K.L.loadingBarbell
            case .flame:    return K.L.loadingFlame
            case .wordmark: return K.L.loadingWordmark
            }
        }
    }

    @State private var appeared = false
    /// Drives the continuous loop (bob / flicker / breathe) once the entrance settles.
    @State private var loop = false

    private var style: LoadingStyle {
        LoadingStyle(rawValue: LocalStore.shared.loadingStyle) ?? .barbell
    }

    var body: some View {
        ZStack {
            GymBackground().ignoresSafeArea()
            VStack(spacing: 18) {
                Group {
                    switch style {
                    case .barbell:  barbellMark
                    case .flame:    flameMark
                    case .wordmark: EmptyView()
                    }
                }
                Text("GymLate")
                    .font(Theme.heading(style == .wordmark ? 34 : 20))
                    .foregroundStyle(
                        LinearGradient(colors: Theme.accentGradient,
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                    .opacity(appeared ? (style == .wordmark && loop ? 0.8 : 1) : 0)
                    .offset(y: appeared ? 0 : 8)
                    .scaleEffect(style == .wordmark && loop ? 1.04 : 1)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) { appeared = true }
            // Continuous loop starts once the entrance spring has settled, so
            // the screen reads as alive the whole time it's on screen rather
            // than a static reveal that just sits there.
            withAnimation(.easeInOut(duration: loopDuration).repeatForever(autoreverses: true).delay(0.5)) {
                loop = true
            }
        }
    }

    private var loopDuration: Double {
        switch style {
        case .barbell:  return 0.85
        case .flame:    return 0.55
        case .wordmark: return 1.1
        }
    }

    // MARK: - Barbell (default)

    /// Geometric barbell: a rounded bar with two plate discs on each side —
    /// mirrors the app's own dumbbell mark without relying on the SF Symbol
    /// (dumbbell.fill only exists on iOS 17+). Bobs up/down with a slight
    /// tilt on a continuous loop, like a rep being lifted.
    private var barbellMark: some View {
        HStack(spacing: 0) {
            plate(size: 34)
            plate(size: 22)
            Capsule()
                .fill(LinearGradient(colors: Theme.accentGradient,
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 46, height: 10)
            plate(size: 22)
            plate(size: 34)
        }
        .scaleEffect(appeared ? 1 : 0.8)
        .rotationEffect(.degrees(appeared ? (loop ? -4 : 0) : -8))
        .offset(y: appeared && loop ? -7 : 0)
    }

    private func plate(size: CGFloat) -> some View {
        Capsule()
            .fill(K.accentDeep)
            .frame(width: 10, height: size)
            .padding(.horizontal, 2)
    }

    // MARK: - Flame

    private var flameMark: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#fb923c").opacity(appeared ? (loop ? 0.6 : 0.4) : 0))
                .frame(width: 90, height: 90)
                .blur(radius: 24)
            Image(systemName: "flame.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    appeared
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color(hex: "#fde047"), Color(hex: "#fb923c"), Color(hex: "#dc2626")],
                        startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color.white.opacity(0.22)))
                .scaleEffect(appeared ? (loop ? 1.1 : 0.95) : 0.82)
                .rotationEffect(.degrees(appeared && loop ? 3 : -3))
        }
    }
}
