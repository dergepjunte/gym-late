import SwiftUI

struct ProfileSetupSheet: View {
    let group: GroupInfo
    let isNew: Bool  // false = joining existing group, show login option

    @EnvironmentObject var appState: AppState
    @Environment(\.pageDismiss) var dismiss
    @State private var mode: Mode = .create
    @State private var name = ""
    @State private var emoji = "🏋️"
    @State private var color = "#7c3aed"
    @State private var recoveryCode = ""
    @State private var error = ""
    @State private var isLoading = false
    @State private var showRecoveryCode = false
    @State private var createdRecoveryCode = ""
    // Recovery codes are retired for brand-new profiles: a create-mode entry
    // with no local account yet is gated behind account creation first, then
    // falls through to this same view once appState.account is populated.
    @State private var showAccountGate = false

    enum Mode { case create, login }

    private let colorOptions = K.avatarColors
    private let emojiOptions = K.avatarEmojis

    var body: some View {
        NavigationStack {
            Form {
                if mode == .create {
                    createSection
                } else {
                    loginSection
                }
                if !error.isEmpty {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GymBackground())
            .navigationTitle(mode == .create ? (K.L.de ? "Profil erstellen" : "Create your profile") : (K.L.de ? "Willkommen zurück!" : "Welcome back!"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .create ? (K.L.de ? "Erstellen" : "Create") : (K.L.de ? "Einloggen" : "Log in")) {
                        Task { await submit() }
                    }
                    .disabled(isLoading || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .fullScreenCover(isPresented: $showRecoveryCode) {
                RecoveryCodeSheet(code: createdRecoveryCode) {
                    showRecoveryCode = false
                    dismiss()
                }
            }
            .fullScreenCover(isPresented: $showAccountGate) {
                AccountAuthSheet(purpose: .signup, onCancel: { dismiss() })
            }
            .onAppear {
                if mode == .create && appState.account == nil { showAccountGate = true }
            }
        }
    }

    private var createSection: some View {
        Group {
            Section(K.L.de ? "Dein Name" : "Your name") {
                TextField(K.L.de ? "Name eingeben…" : "Enter name…", text: $name)
            }
            Section(K.L.epEmojiLbl) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(emojiOptions, id: \.self) { e in
                            Button {
                                emoji = e
                            } label: {
                                Text(e).font(.system(size: 28))
                                    .frame(width: 52, height: 52)
                                    .background(emoji == e ? Color(hex: color).opacity(0.25) : Color(.secondarySystemFill))
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(emoji == e ? Color(hex: color) : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            Section(K.L.epColorLbl) {
                HStack(spacing: 12) {
                    ForEach(colorOptions, id: \.self) { c in
                        Button { color = c } label: {
                            Circle()
                                .fill(Color(hex: c))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(.white, lineWidth: color == c ? 3 : 0)
                                    .padding(2))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !isNew {
                Section {
                    Button(K.L.de ? "Bereits registriert? Einloggen →" : "Already registered? Log in →") {
                        withAnimation { mode = .login }
                    }
                    .foregroundColor(K.accentDark)
                }
            }
        }
    }

    private var loginSection: some View {
        Group {
            Section(K.L.de ? "Dein Name" : "Your name") {
                TextField(K.L.de ? "Name eingeben…" : "Enter name…", text: $name)
            }
            Section("Recovery Code") {
                SecureField("AAAA-BBBB-CCCC", text: $recoveryCode)
                    .textInputAutocapitalization(.characters)
            }
            Section {
                Button(K.L.de ? "Neu hier? Profil erstellen →" : "New here? Create profile →") {
                    withAnimation { mode = .create }
                }
                .foregroundColor(K.accentDark)
            }
        }
    }

    private func submit() async {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { error = K.L.de ? "Bitte Namen eingeben." : "Please enter a name."; return }
        isLoading = true; error = ""
        do {
            if mode == .create {
                let resp = try await APIClient.shared.registerUser(
                    groupId: group.id, name: n, avatarEmoji: emoji, avatarColor: color,
                    accountToken: appState.account?.accountToken)
                let profile = UserProfile(userId: resp.userId, name: resp.name,
                                         avatarEmoji: resp.avatarEmoji, avatarColor: resp.avatarColor,
                                         avatarImg: resp.avatarImg, recoveryCode: resp.recoveryCode,
                                         isCreator: resp.isCreator)
                await appState.enterGroup(group, profile: profile)
                if let code = resp.recoveryCode {
                    createdRecoveryCode = code
                    showRecoveryCode = true
                } else {
                    dismiss()
                }
            } else {
                let resp = try await APIClient.shared.loginUser(
                    groupId: group.id, name: n, recoveryCode: recoveryCode)
                let profile = UserProfile(userId: resp.userId, name: resp.name,
                                         avatarEmoji: resp.avatarEmoji, avatarColor: resp.avatarColor,
                                         avatarImg: resp.avatarImg, recoveryCode: recoveryCode,
                                         isCreator: resp.isCreator)
                await appState.enterGroup(group, profile: profile)
                dismiss()
            }
        } catch APIError.nameTaken {
            error = K.L.errNameTaken
        } catch APIError.unauthorized {
            error = K.L.errWrongCode
        } catch APIError.notFound {
            error = K.L.de ? "Nutzer nicht gefunden." : "User not found."
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct RecoveryCodeSheet: View {
    let code: String
    let onDone: () -> Void
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("🔑")
                    .font(.system(size: 60))
                Text(K.L.de ? "Recovery Code sichern!" : "Save your Recovery Code!")
                    .font(.title2.bold())
                Text(K.L.de ? "Ohne diesen Code kannst du dich auf neuen Geräten nicht einloggen." : "Without this code you can't log in on new devices.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(code)
                    .font(.system(.title2, design: .monospaced).bold())
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .glassCard()
                    .onTapGesture { copyCode() }

                Button { copyCode() } label: {
                    Label(copied ? (K.L.de ? "Kopiert ✓" : "Copied ✓") : (K.L.de ? "Code kopieren" : "Copy Code"), systemImage: "doc.on.doc")
                        .accentButton()
                }
                .padding(.horizontal)

                Button(K.L.de ? "Ich hab's gespeichert! →" : "I've saved it! →") {
                    onDone()
                }
                .foregroundColor(K.accentDark)
                .font(.system(size: 15, weight: .semibold))
            }
            .padding()
            .navigationTitle("Recovery Code")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func copyCode() {
        UIPasteboard.general.string = code
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }
}
