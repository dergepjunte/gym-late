import SwiftUI

/// Netflix-style launch screen (website: #screen-profile-picker) — shown on every
/// cold start when ≥1 group is saved locally, instead of silently re-entering the
/// last-active group. Tapping a saved profile runs the full enter-group ceremony
/// (website: switchToGroup); the "+" tile falls through to LandingView.
struct ProfilePickerView: View {
    @EnvironmentObject var appState: AppState

    private var groups: [GroupInfo] { LocalStore.shared.allGroups }
    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 20)]

    var body: some View {
        ZStack {
            GymBackground()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        Text("🏋️").font(.system(size: 56))
                        Text(K.L.pickerTitle)
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 80)

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(groups) { g in
                            let profile = LocalStore.shared.userProfile(for: g.id)
                            ProfilePickerCard(
                                emoji: profile?.avatarEmoji ?? "🏋️",
                                color: profile?.avatarColor ?? "#7c3aed",
                                img: profile?.avatarImg,
                                name: g.name
                            ) {
                                Task { await appState.switchGroup(g) }
                            }
                        }

                        // Add tile — website: .profile-card-add / .avatar-circle-add
                        Button {
                            appState.showLaunchPicker = false
                        } label: {
                            VStack(spacing: 8) {
                                Circle()
                                    .strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .frame(width: 84, height: 84)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.system(size: 28, weight: .light))
                                            .foregroundColor(.secondary)
                                    )
                                Text(K.L.pickerAdd)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }
        }
    }
}

private struct ProfilePickerCard: View {
    let emoji: String
    let color: String
    let img: String?
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                AvatarView(emoji: emoji, color: color, img: img, size: 84)
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 92)
            }
        }
        .buttonStyle(.plain)
    }
}
