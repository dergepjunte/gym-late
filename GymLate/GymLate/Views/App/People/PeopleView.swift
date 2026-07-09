import SwiftUI

/// Personen tab — mirrors the website's #pane-people:
/// members, invite card, my groups (+ join/create), leave group, admin panel.
struct PeopleView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPerson: Person?
    @State private var adminEditPerson: Person?
    @State private var showJoin = false
    @State private var showCreate = false
    @State private var toast: String?
    @State private var confirmLeave = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(K.L.lblPeople)
                    .font(Theme.heading(24))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if let people = appState.groupData?.people, !people.isEmpty {
                    LazyVStack(spacing: 10) {
                        ForEach(people) { person in
                            PersonRow(person: person,
                                      adminMode: appState.adminMode,
                                      onAdminEdit: { adminEditPerson = person })
                                .onTapGesture {
                                    selectedPerson = person
                                    haptic(.light)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
                    Text(K.L.emptyPeople)
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                }

                // Invite card (website: share hint + "Code teilen" button)
                if let code = appState.activeGroup?.code {
                    VStack(spacing: 10) {
                        Text(K.L.inviteHint)
                            .font(Theme.body(13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        ShareLink(item: code) {
                            Text(K.L.inviteBtn).accentButton()
                        }
                    }
                    .padding(16)
                    .glassCard()
                    .padding(.horizontal, 16)
                }

                // Multi-group section
                VStack(alignment: .leading, spacing: 12) {
                    Text(K.L.mgsTitle).eyebrow()
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    ForEach(LocalStore.shared.allGroups) { g in
                        GroupListRow(group: g, isActive: g.id == appState.activeGroup?.id)
                            .onTapGesture {
                                if g.id != appState.activeGroup?.id {
                                    Task { await appState.switchGroup(g) }
                                }
                            }
                            .padding(.horizontal, 16)
                    }
                }

                // Join / create — the website offers both inline
                HStack(spacing: 12) {
                    Button { showJoin = true } label: {
                        Label(K.L.mgsJoin, systemImage: "link")
                            .font(Theme.body(13, .bold))
                            .foregroundColor(K.amberText)
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .glassCard()
                    }
                    .buttonStyle(.plain)
                    Button { showCreate = true } label: {
                        Label(K.L.mgsCreate, systemImage: "plus.circle")
                            .font(Theme.body(13, .bold))
                            .foregroundColor(K.amberText)
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .glassCard()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                // Leave group (website: red button at the bottom of the tab)
                Button { confirmLeave = true } label: {
                    Text(K.L.leaveGroup)
                        .font(Theme.body(14, .bold))
                        .foregroundColor(K.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(K.red.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                if appState.adminMode {
                    AdminPanelSection(toast: $toast)
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 20)
            }
        }
        .sheet(item: $selectedPerson) { p in ProfileView(person: p) }
        .sheet(item: $adminEditPerson) { p in AdminUserEditSheet(person: p, toast: $toast) }
        .sheet(isPresented: $showJoin) { JoinGroupSheet() }
        .sheet(isPresented: $showCreate) { CreateGroupSheet() }
        .confirmationDialog(K.L.confirmLeave, isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(K.L.leaveGroup, role: .destructive) { appState.leaveCurrentGroup() }
            Button(K.L.cancel, role: .cancel) {}
        }
        .toast($toast)
    }
}

struct PersonRow: View {
    let person: Person
    var adminMode = false
    var onAdminEdit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(emoji: person.avatarEmoji, color: person.avatarColor,
                       img: person.avatarImg, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(person.name).font(Theme.body(15, .bold))
                    if person.isCreator {
                        Image(systemName: "star.fill").foregroundColor(K.gold).font(.system(size: 10))
                    }
                }
                HStack(spacing: 10) {
                    if person.streak > 0 {
                        Label("\(person.streak)", systemImage: "flame.fill")
                            .font(.system(size: 12)).foregroundColor(.orange)
                    }
                    if person.freezes > 0 {
                        Label("\(person.freezes)", systemImage: "snowflake")
                            .font(.system(size: 12)).foregroundColor(.cyan)
                    }
                }
            }
            Spacer()
            if adminMode {
                Button { onAdminEdit?() } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(K.amberText)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(K.accent.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }
            Image(systemName: "chevron.right").foregroundColor(Color(.tertiaryLabel)).font(.system(size: 12))
        }
        .padding(14)
        .glassCard()
    }
}

struct GroupListRow: View {
    let group: GroupInfo
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("🏋️").font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name).font(Theme.body(14, .bold))
                Text(group.code)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isActive {
                Text(K.L.mgsActive).font(Theme.body(11, .bold)).foregroundColor(K.amberText)
            } else {
                Text(K.L.mgsSwitch).font(.system(size: 11)).foregroundColor(.secondary)
            }
        }
        .padding(12)
        .glassCard()
    }
}
