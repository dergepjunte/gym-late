import SwiftUI

// MARK: - Bottom Nav (iOS 17 fallback)

/// Floating Liquid Glass capsule bar. On iOS 26 it uses the real glassEffect;
/// earlier systems fall back to the shared glass recipe. The selected tab
/// carries a yellow gradient pill that slides between items.
struct BottomNav: View {
    @Binding var selected: AppTab
    @Namespace private var pillNS

    var body: some View {
        HStack(spacing: 2) {
            navItem(.week, icon: "house.fill", label: K.L.navHome)
            navItem(.history, icon: "calendar.badge.clock", label: K.L.navHistory)
            navItem(.recap, icon: "chart.bar.fill", label: K.L.navRecap)
            navItem(.people, icon: "person.2.fill", label: K.L.navPeople)
        }
        .padding(5)
        .background(NavGlassCapsule())
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func navItem(_ tab: AppTab, icon: String, label: String) -> some View {
        let isSelected = selected == tab
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { selected = tab }
            haptic(.light)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                Text(label)
                    .font(Theme.body(10, .bold))
            }
            .foregroundColor(isSelected ? K.onAccent : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    Capsule()
                        .fill(LinearGradient(colors: Theme.accentGradient,
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(
                            Capsule().fill(LinearGradient(
                                stops: [.init(color: .white.opacity(0.40), location: 0),
                                        .init(color: .clear, location: 0.5)],
                                startPoint: .top, endPoint: .bottom))
                        )
                        .matchedGeometryEffect(id: "navPill", in: pillNS)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Capsule-shaped Liquid Glass base for the floating nav bar.
private struct NavGlassCapsule: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let g = Theme.Glass.tokens(for: scheme)
        Group {
            if #available(iOS 26.0, *) {
                Color.clear.glassEffect(.regular.interactive(), in: .capsule)
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .overlay(
            Capsule().fill(LinearGradient(
                stops: [.init(color: g.sheen, location: 0),
                        .init(color: .clear, location: 0.45)],
                startPoint: .topLeading, endPoint: .bottom))
            .allowsHitTesting(false)
        )
        .overlay(
            Capsule().strokeBorder(LinearGradient(
                colors: [g.borderTop, g.border],
                startPoint: .top, endPoint: .bottom), lineWidth: 1)
            .allowsHitTesting(false)
        )
        .shadow(color: g.shadow, radius: 16, x: 0, y: 8)
    }
}
