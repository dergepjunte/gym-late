import SwiftUI

// MARK: - Header (scrolls with each tab's content; self-contained covers)

struct AppHeader: View {
    @EnvironmentObject var appState: AppState
    @Binding var toast: String?

    @State private var logoTaps = 0
    @State private var lastTap = Date.distantPast

    var body: some View {
        ZStack {
            // Center: GYMLATE wordmark + optional admin badge
            HStack(spacing: 6) {
                Text("GYMLATE")
                    .font(Font.system(size: 28, weight: .black).width(.expanded))
                    .textCase(.uppercase)
                    .foregroundStyle(LinearGradient(
                        colors: Theme.accentGradient,
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .onTapGesture { registerLogoTap() }

                if appState.adminMode {
                    Button { appState.showAdminPanel = true } label: {
                        Text("ADMIN")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(K.onAccent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(K.accent))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Right: sync/offline indicator + avatar
            HStack(spacing: 8) {
                Spacer()

                if appState.pendingSyncCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("\(appState.pendingSyncCount)")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(K.accentDeep)
                } else if appState.isOffline {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Button { appState.showMyProfile = true } label: {
                    AvatarView(emoji: appState.userProfile?.avatarEmoji ?? "🏋️",
                               color: appState.userProfile?.avatarColor ?? "#7c3aed",
                               img: appState.userProfile?.avatarImg,
                               size: 44)
                        .overlay(
                            Circle().strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.55),
                                             Color(hex: "#fcd34d").opacity(0.40),
                                             .white.opacity(0.15)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 3.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(K.L.de ? "Mein Profil" : "My profile")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func registerLogoTap() {
        let now = Date()
        if now.timeIntervalSince(lastTap) > 2 { logoTaps = 0 }
        lastTap = now
        logoTaps += 1
        if logoTaps >= 5 {
            logoTaps = 0
            if appState.adminMode {
                appState.adminPassword = nil
                toast = K.L.toastAdmOut
            } else {
                appState.showAdminLogin = true
            }
            haptic(.medium)
        }
    }
}
