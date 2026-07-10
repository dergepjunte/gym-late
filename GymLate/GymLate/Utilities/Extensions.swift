import SwiftUI

// MARK: - Liquid Glass surface

/// Shared Liquid Glass recipe: base material (iOS 26 glassEffect or ultraThinMaterial),
/// gloss sheen fading out at 45%, 1px border brighter at the top edge, soft warm shadow.
struct GlassSurface: ViewModifier {
    var radius: CGFloat = 20
    var interactive: Bool = false
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let g = Theme.Glass.tokens(for: scheme)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background {
                if #available(iOS 26.0, *) {
                    Color.clear.glassEffect(
                        interactive ? .regular.interactive() : .regular,
                        in: .rect(cornerRadius: radius))
                } else {
                    shape.fill(.ultraThinMaterial)
                }
            }
            .overlay {
                shape.fill(LinearGradient(
                    stops: [.init(color: g.sheen, location: 0),
                            .init(color: .clear, location: 0.45)],
                    startPoint: .topLeading, endPoint: .bottom))
                .allowsHitTesting(false)
            }
            .overlay {
                shape.strokeBorder(LinearGradient(
                    colors: [g.borderTop, g.border],
                    startPoint: .top, endPoint: .bottom), lineWidth: 1)
                .allowsHitTesting(false)
            }
            .clipShape(shape)
            .shadow(color: g.shadow, radius: 16, x: 0, y: 8)
    }
}

extension View {
    /// Liquid Glass surface for content cards.
    func glassCard(radius: CGFloat = 20) -> some View {
        modifier(GlassSurface(radius: radius))
    }

    /// Prominent accent call-to-action. Tinted, interactive Liquid Glass on iOS 26+.
    @ViewBuilder
    func accentButton() -> some View {
        let base = self
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(K.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        if #available(iOS 26.0, *) {
            base.glassEffect(.regular.tint(K.accent).interactive(),
                             in: .rect(cornerRadius: 16))
        } else {
            base.background(
                LinearGradient(
                    colors: Theme.accentGradient,
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                .cornerRadius(16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(
                        stops: [.init(color: .white.opacity(0.35), location: 0),
                                .init(color: .clear, location: 0.45)],
                        startPoint: .topLeading, endPoint: .bottom))
                    .allowsHitTesting(false)
            )
        }
    }

    /// Secondary, untinted Liquid Glass button surface.
    func glassButton(radius: CGFloat = 16) -> some View {
        modifier(GlassSurface(radius: radius, interactive: true))
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
        content.overlay {
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.black.opacity(0.8)))
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
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            // All-warm palette: dominant amber, rosé counterpoint (ties into the
            // Wrapped slide pinks), orange base glow near the nav bar.
            RadialGradient(colors: [Color(hex: dark ? "#fbbf24" : "#f59e0b").opacity(dark ? 0.18 : 0.20), .clear],
                          center: .init(x: 0.18, y: 0.10), startRadius: 0, endRadius: 340)
            .ignoresSafeArea()
            RadialGradient(colors: [Color(hex: dark ? "#f472b6" : "#fb7185").opacity(dark ? 0.09 : 0.08), .clear],
                          center: .init(x: 0.86, y: 0.26), startRadius: 0, endRadius: 250)
            .ignoresSafeArea()
            RadialGradient(colors: [Color(hex: dark ? "#f97316" : "#fb923c").opacity(dark ? 0.11 : 0.10), .clear],
                          center: .init(x: 0.55, y: 0.95), startRadius: 0, endRadius: 320)
            .ignoresSafeArea()
        }
    }
}
