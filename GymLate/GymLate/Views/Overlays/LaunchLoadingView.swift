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
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) { appeared = true }
        }
    }

    // MARK: - Barbell (default)

    /// Geometric barbell: a rounded bar with two plate discs on each side —
    /// mirrors the app's own dumbbell mark without relying on the SF Symbol
    /// (dumbbell.fill only exists on iOS 17+).
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
        .rotationEffect(.degrees(appeared ? 0 : -8))
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
                .fill(Color(hex: "#fb923c").opacity(appeared ? 0.45 : 0))
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
                .scaleEffect(appeared ? 1 : 0.82)
        }
    }
}
