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
