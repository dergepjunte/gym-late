import SwiftUI

struct PeopleView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPerson: Person?
    @State private var showGroupSwitcher = false
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Mitglieder")
                    .font(Theme.heading(24))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if let people = appState.groupData?.people, !people.isEmpty {
                    LazyVStack(spacing: 10) {
                        ForEach(people) { person in
                            PersonRow(person: person)
                                .onTapGesture {
                                    selectedPerson = person
                                    haptic(.light)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
                    Text("Noch keine Mitglieder")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                }

                // Invite card
                if let code = appState.activeGroup?.code {
                    Button {
                        UIPasteboard.general.string = code
                        toast = K.L.toastCopied
                        hapticSuccess()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(K.accentDeep)
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Freunde einladen")
                                    .font(Theme.body(14, .bold))
                                    .foregroundColor(.primary)
                                Text("Code teilen: \(code)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(K.accentDark)
                                .font(.system(size: 14))
                        }
                        .padding(14)
                        .glassCard()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }

                Divider().padding(.vertical, 8)

                // Multi-group section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Meine Gruppen").eyebrow()
                        .padding(.horizontal, 20)
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

                HStack(spacing: 12) {
                    Button { showGroupSwitcher = true } label: {
                        Label("Gruppe beitreten", systemImage: "link")
                            .font(Theme.body(14, .bold))
                            .foregroundColor(K.amberText)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .glassCard()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .sheet(item: $selectedPerson) { p in ProfileView(person: p) }
        .sheet(isPresented: $showGroupSwitcher) { GroupSwitcherSheet() }
        .toast($toast)
    }
}

struct PersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(hex: person.avatarColor).opacity(0.2)).frame(width: 48, height: 48)
                Text(person.avatarEmoji).font(.system(size: 26))
            }
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
                Text("Aktiv").font(Theme.body(11, .bold)).foregroundColor(K.amberText)
            } else {
                Text("Wechseln").font(.system(size: 11)).foregroundColor(.secondary)
            }
        }
        .padding(12)
        .glassCard()
    }
}
