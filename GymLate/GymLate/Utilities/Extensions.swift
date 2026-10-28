import SwiftUI

// MARK: - Steel plate surface ("Iron" design, v0.3)

/// Shared surface recipe: brushed graphite steel — a dark vertical gradient, a fine
/// top highlight like a machined edge, a hairline border and a heavy drop shadow.
/// (Kept the old name so every card in the app picks up the new look.)
struct GlassSurface: ViewModifier {
    var radius: CGFloat = 16
    var interactive: Bool = false
    var capsule: Bool = false

    func body(content: Content) -> some View {
        let shape: AnyShape = capsule
            ? AnyShape(Capsule())
            : AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        return content
            .background {
                ZStack {
                    shape.fill(LinearGradient(colors: [K.iron2, K.iron1],
                                              startPoint: .top, endPoint: .bottom))
                    // Brushed-metal grain: very faint horizontal lines.
                    BrushedGrain().clipShape(shape).opacity(0.5)
                }
            }
            .overlay {
                shape.stroke(LinearGradient(
                    stops: [.init(color: .white.opacity(0.18), location: 0),
                            .init(color: .white.opacity(0.05), location: 0.35),
                            .init(color: .black.opacity(0.5), location: 1)],
                    startPoint: .top, endPoint: .bottom), lineWidth: 1)
                .allowsHitTesting(false)
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(0.55), radius: 14, x: 0, y: 8)
    }
}

/// Faint brushed-steel texture (static, drawn once per size).
struct BrushedGrain: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            var i = 0
            while y < size.height {
                let a = 0.018 + 0.02 * Double((i * 7919) % 5) / 5
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                         with: .color(.white.opacity(a)))
                y += 3; i += 1
            }
        }
        .allowsHitTesting(false)
    }
}

/// Yellow/black hazard-tape stripes.
struct HazardStripes: View {
    var stripe: CGFloat = 10
    var color: Color = K.accent
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "#111111")))
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                p.addLine(to: CGPoint(x: x + size.height + stripe, y: 0))
                p.addLine(to: CGPoint(x: x + stripe, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(color))
                x += stripe * 2
            }
        }
        .allowsHitTesting(false)
    }
}

/// Pressable feel for slab buttons: sink + darken on touch.
struct SlabPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension View {
    /// Steel plate surface for content cards.
    func glassCard(radius: CGFloat = 16) -> some View {
        modifier(GlassSurface(radius: radius))
    }

    /// Steel card with a yellow load-bar on the left edge — for the key card on a screen.
    func ironCard(radius: CGFloat = 16, accent: Color = K.accent) -> some View {
        self.modifier(GlassSurface(radius: radius))
            .overlay(alignment: .leading) {
                UnevenRoundedRectangle(topLeadingRadius: radius, bottomLeadingRadius: radius,
                                       style: .continuous)
                    .fill(accent).frame(width: 4)
                    .allowsHitTesting(false)
            }
    }

    /// Primary call-to-action: a solid safety-yellow slab with black stencil lettering.
    func accentButton() -> some View {
        self
            .font(.system(size: 17, weight: .black).width(.condensed))
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundColor(K.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [K.accentLight, K.accent, K.accentDeep],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.55), .black.opacity(0.25)],
                                           startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: K.accent.opacity(0.28), radius: 14, x: 0, y: 6)
    }

    /// Secondary button surface: dark steel pill.
    func glassButton(radius: CGFloat = 16) -> some View {
        modifier(GlassSurface(radius: radius, interactive: true, capsule: true))
    }

    /// Right-to-left push page cover (replaces .fullScreenCover).
    func fullPageCover<C: View>(isPresented: Binding<Bool>,
                                @ViewBuilder content: @escaping () -> C) -> some View {
        modifier(FullPageModifier(isPresented: isPresented, pageContent: content))
    }

    /// Item-based variant of fullPageCover.
    func fullPageCover<Item: Identifiable, C: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> C
    ) -> some View {
        fullPageCover(isPresented: Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )) {
            if let i = item.wrappedValue { content(i) }
        }
    }
}

// MARK: - Full-page dismiss environment key

private struct PageDismissKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Dismiss action injected by fullPageCover; call like dismiss().
    var pageDismiss: () -> Void {
        get { self[PageDismissKey.self] }
        set { self[PageDismissKey.self] = newValue }
    }
}

private struct FullPageModifier<PageContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let pageContent: () -> PageContent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            // Die darunterliegende Seite weicht zurueck (kleiner, dunkler, abgerundet), waehrend die neue einfaehrt.
            // mask statt clipShape: clipShape wuerde Hintergruende im Sicherheitsbereich abschneiden (schwarze Balken).
            .mask(RoundedRectangle(cornerRadius: isPresented && !reduceMotion ? 30 : 0, style: .continuous).ignoresSafeArea())
            .scaleEffect(isPresented && !reduceMotion ? 0.94 : 1)
            .offset(x: isPresented && !reduceMotion ? -36 : 0)
            .brightness(isPresented && !reduceMotion ? -0.14 : 0)
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isPresented)
            .overlay {
            Group {
                if isPresented {
                    pageContent()
                        .environment(\.pageDismiss) {
                            let anim: Animation = reduceMotion
                                ? .easeOut(duration: 0.2)
                                : .spring(response: 0.38, dampingFraction: 0.82)
                            withAnimation(anim) { isPresented = false }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                        .transition(reduceMotion ? .opacity : .move(edge: .trailing))
                }
            }
            .animation(
                reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.82),
                value: isPresented
            )
        }
    }
}

// MARK: - ZigzagBorder

/// Closed sawtooth path that follows the four edges of its rect.
/// Use as `.overlay { ZigzagBorder().stroke(color, lineWidth: w) }`.
struct ZigzagBorder: Shape {
    var amplitude: CGFloat = 3
    var wavelength: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let edges: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: 0, y: 1)),
            (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: -1, y: 0)),
            (CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: 0, y: -1)),
            (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: 1, y: 0))
        ]
        var isFirst = true
        for (start, end, normal) in edges {
            let length = hypot(end.x - start.x, end.y - start.y)
            let steps = max(2, Int(length / wavelength))
            let dx = (end.x - start.x) / length
            let dy = (end.y - start.y) / length
            let stepLen = length / CGFloat(steps)
            if isFirst { path.move(to: start); isFirst = false }
            for i in 0..<steps {
                let midT = (CGFloat(i) + 0.5) * stepLen
                let endT = CGFloat(i + 1) * stepLen
                let mid  = CGPoint(x: start.x + dx * midT + normal.x * amplitude,
                                   y: start.y + dy * midT + normal.y * amplitude)
                let next = CGPoint(x: start.x + dx * endT, y: start.y + dy * endT)
                path.addLine(to: mid)
                path.addLine(to: next)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - String

extension String {
    var normalizedRecoveryCode: String {
        self.replacingOccurrences(of: "-", with: "").uppercased()
    }
}

// MARK: - Date

extension Date {
    var ymdhString: String { dateYMD(self) }
    var isoWeekStart: Date { Calendar.iso8601UTC.startOfWeek(for: self) }
}

// MARK: - Localized date strings (mirror the website's fmtShort/fmtFull)

/// "6. Juli" / "Jul 6" — short day+month in the user's locale.
func fmtShort(_ ymd: String) -> String {
    guard let d = parseDate(ymd) else { return ymd }
    let f = DateFormatter()
    f.timeZone = TimeZone(identifier: "UTC")
    f.setLocalizedDateFormatFromTemplate("d MMM")
    return f.string(from: d)
}

/// "Mo., 6. Juli" / "Mon, Jul 6" — weekday+day+month in the user's locale.
func fmtFull(_ ymd: String) -> String {
    guard let d = parseDate(ymd) else { return ymd }
    let f = DateFormatter()
    f.timeZone = TimeZone(identifier: "UTC")
    f.setLocalizedDateFormatFromTemplate("EEE d MMM")
    return f.string(from: d)
}

/// Up to two initials, like the website's `initials()`.
func initials(_ name: String) -> String {
    let parts = name.split(separator: " ")
    if parts.count >= 2, let a = parts[0].first, let b = parts[1].first {
        return String([a, b]).uppercased()
    }
    return String(name.prefix(2)).uppercased()
}

/// Mon=0 … Sun=6 index for a yyyy-MM-dd date (ISO week order).
func isoWeekdayIndex(_ ymd: String) -> Int {
    guard let d = parseDate(ymd) else { return 0 }
    let w = Calendar.iso8601UTC.component(.weekday, from: d) // 1=Sun
    return w == 1 ? 6 : w - 2
}

/// True when the gym-days mask marks this date as a scheduled day.
func dayScheduled(_ ymd: String, mask: String) -> Bool {
    guard mask.count == 7 else { return false }
    return Array(mask)[isoWeekdayIndex(ymd)] == "1"
}

// MARK: - Haptics

import UIKit

func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}

func hapticSuccess() {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
}

// MARK: - Toast

struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let msg = message {
                Text(msg)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(K.onAccent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(K.accent))
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { message = nil }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.35), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

// MARK: - Gradient Background

struct GymBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Gym floor at night: graphite base, rubber-floor speckle, a hanging spotlight
    /// that sways very slowly from the top, and a warm yellow bounce light near the floor.
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { ctx in
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                K.iron0.ignoresSafeArea()
                RubberFloor().ignoresSafeArea().opacity(0.9)
                // Overhead spotlight cone
                RadialGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.03), .clear],
                               center: .init(x: 0.5 + 0.06 * sin(t / 9), y: -0.05),
                               startRadius: 0, endRadius: 520)
                    .ignoresSafeArea()
                // Safety-yellow glow, top-left and bottom
                RadialGradient(colors: [K.accent.opacity(0.13), .clear],
                               center: .init(x: 0.12 + 0.05 * sin(t / 11), y: 0.08),
                               startRadius: 0, endRadius: 340)
                    .ignoresSafeArea()
                RadialGradient(colors: [K.accentDeep.opacity(0.10), .clear],
                               center: .init(x: 0.7 + 0.08 * cos(t / 13), y: 1.02),
                               startRadius: 0, endRadius: 380)
                    .ignoresSafeArea()
                // Vignette
                RadialGradient(colors: [.clear, Color.black.opacity(0.55)],
                               center: .center, startRadius: 160, endRadius: 640)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

/// Rubber gym-floor speckle (deterministic, drawn once).
private struct RubberFloor: View {
    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func rnd() -> CGFloat {
                seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
                return CGFloat(seed % 10_000) / 10_000
            }
            let count = Int(size.width * size.height / 260)
            for _ in 0..<count {
                let x = rnd() * size.width, y = rnd() * size.height
                let r = 0.5 + rnd() * 1.1
                let bright = rnd()
                let c: Color = bright > 0.985 ? K.accent.opacity(0.35)
                    : .white.opacity(0.025 + 0.05 * Double(bright))
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(c))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Screen entrance

/// Weiches Einblenden beim Tab-/Seitenwechsel: Inhalt steigt leicht auf, wird sichtbar und
/// "landet" mit einer Feder. Bei Bewegung reduzieren nur ein Einblenden.
struct ScreenEntrance: ViewModifier {
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 22)
            .scaleEffect(shown || reduceMotion ? 1 : 0.985)
            .onAppear {
                shown = false
                withAnimation(reduceMotion ? .easeOut(duration: 0.2)
                                           : .spring(response: 0.55, dampingFraction: 0.86).delay(0.03)) { shown = true }
            }
    }
}

extension View {
    func screenEntrance() -> some View { modifier(ScreenEntrance()) }
}

// MARK: - Weight-plate frame

/// Wraps content (usually an avatar) in a bumper-plate ring: black rubber rim,
/// yellow stripe, little bolt dots — so people literally sit on the bar.
struct PlateFrame<Content: View>: View {
    var size: CGFloat
    var lit: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [K.iron2, Color(hex: "#050505")],
                                     center: .center, startRadius: size * 0.3, endRadius: size * 0.55))
            Circle()
                .strokeBorder(lit ? K.accent : K.iron3, lineWidth: size * 0.035)
                .padding(size * 0.06)
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: size * 0.035, height: size * 0.035)
                    .offset(y: -size * 0.455)
                    .rotationEffect(.degrees(Double(i) * 45 + 22.5))
            }
            content()
                .frame(width: size * 0.72, height: size * 0.72)
                .clipShape(Circle())
        }
        .frame(width: size, height: size)
        .shadow(color: lit ? K.accent.opacity(0.25) : .clear, radius: 14)
    }
}
