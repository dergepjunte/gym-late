import SwiftUI

/// Netflix-style launch screen (website: #screen-profile-picker) — shown on every
/// cold start when ≥1 group is saved locally, instead of silently re-entering the
/// last-active group. Tapping a saved profile runs the full enter-group ceremony
/// (website: switchToGroup); the "+" tile falls through to LandingView.
struct ProfilePickerView: View {
    @EnvironmentObject var appState: AppState
    @State private var appeared = false
    /// Gewaehltes Profil: es waechst, die anderen weichen, dann beginnt der Gruppenwechsel.
    @State private var selectedId: String?

    private var groups: [GroupInfo] { LocalStore.shared.allGroups }
    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 20)]

    var body: some View {
        ZStack {
            GymBackground()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        Text("🏋️").font(.system(size: 56))
                            .scaleEffect(appeared ? 1 : 0.6)
                        Text(K.L.pickerTitle)
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 80)
                    .opacity(selectedId == nil ? (appeared ? 1 : 0) : 0)
                    .offset(y: appeared ? 0 : -16)

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(Array(groups.enumerated()), id: \.element.id) { index, g in
                            let profile = LocalStore.shared.userProfile(for: g.id)
                            let chosen = selectedId == g.id
                            let others = selectedId != nil && !chosen
                            ProfilePickerCard(
                                emoji: profile?.avatarEmoji ?? "🏋️",
                                color: profile?.avatarColor ?? "#7c3aed",
                                img: profile?.avatarImg,
                                name: g.name
                            ) {
                                guard selectedId == nil else { return }
                                hapticSuccess()
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { selectedId = g.id }
                                Task {
                                    try? await Task.sleep(nanoseconds: 380_000_000)
                                    await appState.switchGroup(g)
                                }
                            }
                            .scaleEffect(chosen ? 1.35 : (others ? 0.7 : (appeared ? 1 : 0.6)))
                            .opacity(others ? 0 : (appeared ? 1 : 0))
                            .offset(y: appeared ? 0 : 28)
                            .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(selectedId == nil ? 0.08 + Double(index) * 0.07 : 0),
                                       value: appeared)
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
                        .opacity(selectedId == nil ? (appeared ? 1 : 0) : 0)
                        .scaleEffect(appeared ? 1 : 0.6)
                        .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.1 + Double(groups.count) * 0.07),
                                   value: appeared)
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }
        }
        .onAppear { appeared = true }
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
