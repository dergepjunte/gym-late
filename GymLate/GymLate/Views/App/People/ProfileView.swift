import SwiftUI

struct ProfileView: View {
    let person: Person
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showEdit = false
    @State private var toast: String?
    @State private var revealRC = false

    private var isMe: Bool {
        appState.userProfile?.userId == person.id
    }

    private var myEntries: [Entry] {
        appState.groupData?.entries.filter { $0.person.lowercased() == person.name.lowercased() } ?? []
    }
    private var lateCount: Int { myEntries.filter { $0.type == "late" }.count }
    private var totalMins: Int { myEntries.filter { $0.type == "late" }.reduce(0) { $0 + $1.mins } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Color(hex: person.avatarColor).opacity(0.25))
                            .frame(width: 100, height: 100)
                        Text(person.avatarEmoji).font(.system(size: 54))
                    }
                    .padding(.top, 16)

                    Text(person.name).font(.title2.bold())
                    if person.isCreator {
                        Label("Gruppenersteller", systemImage: "star.fill")
                            .font(.system(size: 13)).foregroundColor(K.gold)
                    }

                    // Streak / Freezes
                    HStack(spacing: 24) {
                        StatBadge(icon: "flame.fill", color: .orange, value: "\(person.streak)", label: "Streak")
                        StatBadge(icon: "snowflake", color: .cyan, value: "\(person.freezes)", label: "Freezes")
                    }

                    // Late stats
                    HStack(spacing: 24) {
                        StatBadge(icon: "clock.fill", color: K.red, value: "\(lateCount)", label: "Verspätungen")
                        StatBadge(icon: "timer", color: .secondary, value: "\(totalMins)", label: "Min. gesamt")
                    }

                    // Recovery code (only mine)
                    if isMe, let rc = appState.userProfile?.recoveryCode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recovery Code (geheim)")
                                .font(.system(size: 13)).foregroundColor(.secondary)
                            HStack {
                                Text(revealRC ? rc : "XXXX-XXXX-XXXX")
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Button(revealRC ? "verbergen" : "anzeigen") {
                                    revealRC.toggle()
                                }
                                .font(.system(size: 13)).foregroundColor(K.accentDark)
                            }
                        }
                        .padding(16)
                        .glassCard()
                        .padding(.horizontal, 16)
                    }

                    // Action buttons
                    VStack(spacing: 10) {
                        if isMe {
                            Button { showEdit = true } label: {
                                Label("✎ Profil bearbeiten", systemImage: "pencil")
                                    .accentButton()
                            }
                            .padding(.horizontal, 16)
                            Button { kickOrLeave() } label: {
                                Text("Gruppe verlassen")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(K.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(K.red.opacity(0.1).cornerRadius(16))
                            }
                            .padding(.horizontal, 16)
                        } else if appState.userProfile?.isCreator == true {
                            Button { kickUser() } label: {
                                Text("Aus Gruppe entfernen")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(K.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(K.red.opacity(0.1).cornerRadius(16))
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle(person.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .sheet(isPresented: $showEdit) { EditProfileSheet(person: person) }
            .toast($toast)
        }
    }

    private func kickOrLeave() {
        appState.leaveCurrentGroup()
        dismiss()
    }

    private func kickUser() {
        guard let group = appState.activeGroup,
              let actor = appState.userProfile else { return }
        Task {
            do {
                try await APIClient.shared.deleteUser(
                    groupId: group.id, userId: person.id,
                    actorUserId: actor.userId, actorRecoveryCode: actor.recoveryCode)
                await appState.refreshData()
                dismiss()
            } catch {
                toast = K.L.errServer
            }
        }
    }
}

struct StatBadge: View {
    let icon: String; let color: Color; let value: String; let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 18))
            Text(value).font(.system(size: 22, weight: .bold))
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(minWidth: 80)
        .padding(14)
        .glassCard()
    }
}

struct EditProfileSheet: View {
    let person: Person
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var name: String
    @State private var emoji: String
    @State private var color: String
    @State private var error = ""
    @State private var isLoading = false

    private let colorOptions = ["#7c3aed", "#db2777", "#ea580c", "#16a34a", "#0891b2", "#ca8a04"]
    private let emojiOptions = ["🏋️", "💪", "🔥", "⚡", "🎯", "🦾", "🚀", "🏆"]

    init(person: Person) {
        self.person = person
        _name = State(initialValue: person.name)
        _emoji = State(initialValue: person.avatarEmoji)
        _color = State(initialValue: person.avatarColor)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("Name", text: $name) }
                Section("Avatar") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(emojiOptions, id: \.self) { e in
                                Button { emoji = e } label: {
                                    Text(e).font(.system(size: 28))
                                        .frame(width: 52, height: 52)
                                        .background(emoji == e ? Color(hex: color).opacity(0.25) : Color(.secondarySystemFill))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }.padding(.vertical, 4)
                    }
                }
                Section("Farbe") {
                    HStack(spacing: 12) {
                        ForEach(colorOptions, id: \.self) { c in
                            Button { color = c } label: {
                                Circle().fill(Color(hex: c)).frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(.white, lineWidth: color == c ? 3 : 0).padding(2))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                if !error.isEmpty { Section { Text(error).foregroundColor(.red) } }
            }
            .navigationTitle("Profil bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { Task { await save() } }.disabled(isLoading)
                }
            }
        }
    }

    private func save() async {
        guard let group = appState.activeGroup, let profile = appState.userProfile else { return }
        isLoading = true
        do {
            let synced = try await SyncEngine.shared.submitPatchUser(
                groupId: group.id, userId: person.id,
                name: name, avatarEmoji: emoji, avatarColor: color,
                recoveryCode: profile.recoveryCode)
            if synced {
                await appState.refreshData()
            }
            dismiss()
        } catch APIError.nameTaken {
            error = "Dieser Name ist bereits vergeben."
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
