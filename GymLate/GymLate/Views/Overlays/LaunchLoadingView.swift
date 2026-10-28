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

    @EnvironmentObject private var appState: AppState
    @State private var appeared = false
    /// Drives the continuous loop (bob / flicker / breathe) once the entrance settles.
    @State private var loop = false
    /// Ruhelage fuer den Zoom: Schleifen-Pose zurueck auf neutral, damit der Ankerpunkt stimmt.
    @State private var calm = false
    @State private var zoom = false
    @State private var cover = false
    @State private var spec: GlyphZoomSpec?
    @State private var maxScale: CGFloat = 1

    private var style: LoadingStyle {
        LoadingStyle(rawValue: LocalStore.shared.loadingStyle) ?? .barbell
    }

    private var reduce: Bool { UIAccessibility.isReduceMotionEnabled }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                GymBackground().ignoresSafeArea()
                // Fuellt Luecken, falls der Zoom am Ende nicht ganz bis in jede Ecke reicht.
                if let spec {
                    Rectangle().fill(spec.color).ignoresSafeArea().opacity(cover ? 1 : 0)
                }
                VStack(spacing: 18) {
                    switch style {
                    case .barbell:  zoomable(barbellMark)
                    case .flame:    flameMark
                    case .wordmark: EmptyView()
                    }
                    wordmark
                }
                .onChange(of: appState.bootFilling) { _, filling in
                    if filling { startZoom(in: geo.size) }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) { appeared = true }
            // Continuous loop starts once the entrance spring has settled, so
            // the screen reads as alive the whole time it's on screen rather
            // than a static reveal that just sits there. Skipped entirely
            // under Reduce Motion (matches the pattern used for the
            // notification bubble transition in AppRootView.swift).
            guard !UIAccessibility.isReduceMotionEnabled else { return }
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

    // MARK: - Zoom

    /// Das gemessene Motiv waehrend des Zooms; bei Barbell/Flame ist es die Grafik, beim Schriftzug der Text.
    private func startZoom(in size: CGSize) {
        let measured: GlyphZoomSpec?
        switch style {
        case .barbell:  measured = GlyphMeasure.measure(barbellGlyph)
        case .flame:    measured = GlyphMeasure.measure(flameGlyph)
        case .wordmark: measured = GlyphMeasure.measure(wordmarkText)
        }
        guard let measured else {
            // Notfall: Messung nicht moeglich → Ueberblendung in Akzentfarbe.
            spec = GlyphZoomSpec(anchor: .center, inradius: 1, color: K.accentDeep)
            withAnimation(.easeIn(duration: 0.5)) { cover = true }
            return
        }
        spec = measured
        // Der Anker kann bis zur Haelfte der Motivgroesse neben der Bildschirmmitte liegen.
        let reach = hypot(size.width, size.height) / 2 + 220
        maxScale = max(8, reach / max(measured.inradius, 0.5) * 1.1)
        withAnimation(.easeOut(duration: 0.2)) { calm = true; loop = false }
        guard !reduce else {
            withAnimation(.easeIn(duration: 0.3)) { cover = true }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            // Starkes Ease-in: erst langsam, dann rasant wachsend (wirkt wie gleichmaessiger Zoom).
            withAnimation(.timingCurve(0.75, 0.0, 0.9, 0.35, duration: 0.8)) { zoom = true }
            withAnimation(.easeIn(duration: 0.15).delay(0.68)) { cover = true }
        }
    }

    @ViewBuilder
    private func zoomable<V: View>(_ content: V) -> some View {
        if let spec {
            content.scaleEffect(zoom ? maxScale : 1, anchor: spec.anchor)
        } else {
            content
        }
    }

    // MARK: - Wordmark / Label

    private var wordmarkText: some View {
        Text("GYMLATE")
            .font(Theme.display(style == .wordmark ? 64 : 34))
            .foregroundStyle(
                LinearGradient(colors: Theme.accentGradient,
                               startPoint: .top, endPoint: .bottom))
    }

    @ViewBuilder
    private var wordmark: some View {
        let filling = appState.bootFilling
        let base = wordmarkText
            .opacity(appeared ? (style == .wordmark && loop ? 0.8 : 1) : 0)
            .offset(y: appeared ? 0 : 8)
            .scaleEffect(style == .wordmark && loop ? 1.04 : 1)
        if style == .wordmark {
            zoomable(base)
        } else {
            base.opacity(filling ? 0 : 1).animation(.easeOut(duration: 0.2), value: filling)
        }
    }

    // MARK: - Barbell (default)

    /// Geometric barbell: a rounded bar with two plate discs on each side —
    /// mirrors the app's own dumbbell mark without relying on the SF Symbol
    /// (dumbbell.fill only exists on iOS 17+). Bobs up/down with a slight
    /// tilt on a continuous loop, like a rep being lifted.
    private var barbellGlyph: some View {
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
    }

    private var barbellMark: some View {
        barbellGlyph
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

    private var flameGlyph: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: 56))
            .foregroundStyle(LinearGradient(
                colors: [Color(hex: "#fde047"), Color(hex: "#fb923c"), Color(hex: "#dc2626")],
                startPoint: .top, endPoint: .bottom))
    }

    private var flameMark: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#fb923c").opacity(appeared ? (loop ? 0.6 : 0.4) : 0))
                .frame(width: 90, height: 90)
                .blur(radius: 24)
                .opacity(appState.bootFilling ? 0 : 1)
                .animation(.easeOut(duration: 0.2), value: appState.bootFilling)
            zoomable(
                flameGlyph
                    .opacity(appeared ? 1 : 0.22)
                    .scaleEffect(appeared ? (calm ? 1 : (loop ? 1.1 : 0.95)) : 0.82)
                    .rotationEffect(.degrees(appeared && loop ? 3 : -3))
            )
        }
    }
}
