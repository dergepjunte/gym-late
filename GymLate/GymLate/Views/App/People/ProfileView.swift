import SwiftUI
import PhotosUI

/// Member profile (website: #modal-profile-view) — avatar, creator badge,
/// stat cards, gym-day chips, own recovery code + edit, kick/leave.
struct ProfileView: View {
    let person: Person
    @EnvironmentObject var appState: AppState
    @Environment(\.pageDismiss) var dismiss
    @State private var showEdit = false
    @State private var showSettings = false
    @State private var toast: String?
    @State private var revealRC = false
    @State private var confirmKick = false
    @State private var confirmLeave = false

    private var isMe: Bool {
        appState.userProfile?.userId == person.id
    }

    private var myEntries: [Entry] {
        appState.groupData?.entries.filter { $0.person.lowercased() == person.name.lowercased() } ?? []
    }
    private var lateCount: Int { myEntries.filter { $0.type == "late" }.count }
    private var totalMins: Int { myEntries.filter { $0.type == "late" }.reduce(0) { $0 + $1.mins } }

    /// Days this member actually trains: group mask ∩ personal availability.
    private var gymDayFlags: [Bool] {
        let group = appState.groupData?.gymDays ?? "1111111"
        let avail = person.availDays ?? "1111111"
        guard group.count == 7, avail.count == 7 else { return Array(repeating: false, count: 7) }
        return zip(group, avail).map { $0 == "1" && $1 == "1" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    AvatarView(emoji: person.avatarEmoji, color: person.avatarColor,
                               img: person.avatarImg, size: 100)
                        .padding(.top, 16)

                    Text(person.name).font(.title2.bold())
                    if person.isCreator {
                        Label(K.L.pvCreatorBadge, systemImage: "star.fill")
                            .font(.system(size: 13)).foregroundColor(K.gold)
                    }

                    // Streak / Freezes
                    HStack(spacing: 24) {
                        StatBadge(icon: "flame.fill", color: .orange, value: "\(person.streak)", label: K.L.streak)
                        StatBadge(icon: "snowflake", color: .cyan, value: "\(person.freezes)", label: K.L.freezes)
                    }

                    // Late stats (website: stat cards)
                    HStack(spacing: 24) {
                        StatBadge(icon: "clock.fill", color: K.red, value: "\(lateCount)", label: K.L.pvStatCount)
                        StatBadge(icon: "timer", color: .secondary, value: "\(totalMins)", label: K.L.pvStatMins)
                    }

                    // Gym day chips (website: pv-day-chips)
                    VStack(spacing: 8) {
                        Text(K.L.pvGymDaysLbl)
                            .font(Theme.body(12)).foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            ForEach(0..<7, id: \.self) { i in
                                Text(K.L.dayNames[i])
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(width: 34, height: 34)
                                    .background(gymDayFlags[i] ? K.accent : Color(.secondarySystemFill))
                                    .foregroundColor(gymDayFlags[i] ? K.onAccent : .secondary)
                                    .clipShape(Circle())
                            }
                        }
                    }

                    // Recovery code (only mine)
                    if isMe, let rc = appState.userProfile?.recoveryCode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(K.L.pvRcLbl)
                                .font(.system(size: 13)).foregroundColor(.secondary)
                            HStack {
                                Text(revealRC ? rc : "AAAA-BBBB-CCCC")
                                    .font(.system(.body, design: .monospaced))
                                    .onTapGesture {
                                        guard revealRC else { return }
                                        UIPasteboard.general.string = rc
                                        toast = K.L.pvRcCopied
                                    }
                                Spacer()
                                if revealRC {
                                    Button {
                                        UIPasteboard.general.string = rc
                                        toast = K.L.pvRcCopied
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 14))
                                            .foregroundColor(K.accentDark)
                                    }
                                }
                                Button(revealRC ? K.L.pvHide : K.L.pvReveal) {
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
                                Label(K.L.pvEditBtn, systemImage: "pencil")
                                    .accentButton()
                            }
                            .padding(.horizontal, 16)
                            Button { confirmLeave = true } label: {
                                Text(K.L.leaveGroup)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(K.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(K.red.opacity(0.1).clipShape(Capsule()))
                            }
                            .padding(.horizontal, 16)
                        } else if appState.userProfile?.isCreator == true || appState.adminMode {
                            Button { confirmKick = true } label: {
                                Text(K.L.pvKickBtn)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(K.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(K.red.opacity(0.1).clipShape(Capsule()))
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    Spacer(minLength: 20)
                }
            }
            .background(GymBackground())
            .navigationTitle(person.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                if isMe {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showEdit) { EditProfileSheet(person: person) }
            .fullScreenCover(isPresented: $showSettings) { SettingsSheet() }
            .confirmationDialog(K.L.pvKickConfirm(person.name), isPresented: $confirmKick,
                                titleVisibility: .visible) {
                Button(K.L.pvKickBtn, role: .destructive) { kickUser() }
                Button(K.L.cancel, role: .cancel) {}
            }
            .confirmationDialog(K.L.confirmLeave, isPresented: $confirmLeave,
                                titleVisibility: .visible) {
                Button(K.L.leaveGroup, role: .destructive) {
                    appState.leaveCurrentGroup()
                    dismiss()
                }
                Button(K.L.cancel, role: .cancel) {}
            }
            .toast($toast)
        }
    }

    private func kickUser() {
        guard let group = appState.activeGroup,
              let actor = appState.userProfile else { return }
        Task {
            do {
                try await APIClient.shared.deleteUser(
                    groupId: group.id, userId: person.id,
                    actorUserId: actor.userId, actorRecoveryCode: actor.recoveryCode,
                    accountToken: appState.account?.accountToken,
                    adminPassword: appState.adminPassword)
                await appState.refreshData()
                toast = K.L.toastKicked
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

// MARK: - Edit profile (website: #modal-edit-profile, incl. photo upload)

struct EditProfileSheet: View {
    let person: Person
    @EnvironmentObject var appState: AppState
    @Environment(\.pageDismiss) var dismiss
    @State private var name: String
    @State private var emoji: String
    @State private var color: String
    @State private var img: String?
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var error = ""
    @State private var isLoading = false

    init(person: Person) {
        self.person = person
        _name = State(initialValue: person.name)
        _emoji = State(initialValue: person.avatarEmoji)
        _color = State(initialValue: person.avatarColor)
        _img = State(initialValue: person.avatarImg)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        AvatarView(emoji: emoji, color: color, img: img, size: 84)
                        if img != nil {
                            Button(K.L.removePhoto, role: .destructive) {
                                img = nil
                                pickedPhoto = nil
                            }
                            .font(Theme.body(13, .semibold))
                        } else {
                            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                                Text(K.L.uploadPhoto)
                                    .font(Theme.body(13, .semibold))
                                    .foregroundColor(K.amberText)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                Section(K.L.epNameLbl) { TextField(K.L.epNameLbl, text: $name) }
                Section(K.L.epEmojiLbl) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(K.avatarEmojis, id: \.self) { e in
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
                Section(K.L.epColorLbl) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(K.avatarColors, id: \.self) { c in
                            Button { color = c } label: {
                                Circle().fill(Color(hex: c)).frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(.white, lineWidth: color == c ? 3 : 0).padding(2))
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                if !error.isEmpty { Section { Text(error).foregroundColor(.red) } }
            }
            .navigationTitle(K.L.epTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(K.L.save) { Task { await save() } }.disabled(isLoading)
                }
            }
            .onChange(of: pickedPhoto) { _, item in
                Task { await loadPhoto(item) }
            }
        }
    }

    /// Downscale + JPEG-encode the picked photo into a data URL — same format
    /// and 400 KB limit the server enforces for the web upload.
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let ui = UIImage(data: data) else { return }
        let side: CGFloat = 256
        let scale = max(side / ui.size.width, side / ui.size.height)
        let newSize = CGSize(width: ui.size.width * scale, height: ui.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in ui.draw(in: CGRect(origin: .zero, size: newSize)) }
        var quality: CGFloat = 0.8
        var jpeg = resized.jpegData(compressionQuality: quality)
        while let d = jpeg, d.count > 280_000, quality > 0.2 {
            quality -= 0.15
            jpeg = resized.jpegData(compressionQuality: quality)
        }
        guard let jpeg else { return }
        img = "data:image/jpeg;base64," + jpeg.base64EncodedString()
    }

    private func save() async {
        guard let group = appState.activeGroup, let profile = appState.userProfile else { return }
        isLoading = true
        do {
            // avatarImg goes through the direct API call — the server treats a
            // present-but-null value as "remove photo".
            try await APIClient.shared.patchUser(
                groupId: group.id, userId: person.id,
                name: name, avatarEmoji: emoji, avatarColor: color,
                avatarImg: img ?? "",
                recoveryCode: profile.recoveryCode, accountToken: appState.account?.accountToken)
            var updated = profile
            updated.name = name
            updated.avatarEmoji = emoji
            updated.avatarColor = color
            updated.avatarImg = img
            LocalStore.shared.saveUserProfile(updated, for: group.id)
            appState.userProfile = updated
            await appState.refreshData()
            dismiss()
        } catch APIError.nameTaken {
            error = K.L.errNameTaken
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
