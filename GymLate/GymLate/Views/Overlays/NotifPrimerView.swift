import SwiftUI

/// Apple-style notification priming prompt (website: #notif-primer).
/// Shown once on first launch after joining a group. Cannot be dismissed by
/// tapping the backdrop — only the two action buttons close it, so the user
/// actually reads what they're opting into.
struct NotifPrimerView: View {
    @EnvironmentObject var appState: AppState
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.70).ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 28) {
                    // Icon glyph
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(K.accentDeep.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(K.accentDeep)
                    }

                    // Copy
                    VStack(spacing: 10) {
                        Text(K.L.notifPrimerTitle)
                            .font(.system(size: 22, weight: .bold))
                            .multilineTextAlignment(.center)
                        Text(K.L.notifPrimerBody)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    // Buttons
                    VStack(spacing: 10) {
                        Button {
                            dismiss(allowed: true)
                            hapticSuccess()
                        } label: {
                            Text(K.L.notifPrimerEnable)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(K.onAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(LinearGradient(
                                            colors: Theme.accentGradient,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing))
                                )
                        }
                        .buttonStyle(.plain)

                        Button { dismiss(allowed: false) } label: {
                            Text(K.L.notifPrimerLater)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
                )
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { opacity = 1 }
        }
        // No tap-through dismiss — only buttons close this view
        .allowsHitTesting(true)
    }

    private func dismiss(allowed: Bool) {
        LocalStore.shared.notifPrimerSeen = true
        withAnimation(.easeOut(duration: 0.2)) { opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            appState.showNotifPrimer = false
        }
        if allowed {
            Task { await NotificationManager.shared.requestPermission() }
        }
    }
}
