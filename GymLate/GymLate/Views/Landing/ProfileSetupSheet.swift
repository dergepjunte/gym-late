import SwiftUI

struct ProfileSetupSheet: View {
    let group: GroupInfo
    let isNew: Bool  // false = joining existing group, show login option

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var mode: Mode = .create
    @State private var name = ""
    @State private var emoji = "🏋️"
    @State private var color = "#7c3aed"
    @State private var recoveryCode = ""
    @State private var error = ""
    @State private var isLoading = false
    @State private var showRecoveryCode = false
    @State private var createdRecoveryCode = ""

    enum Mode { case create, login }

    private let colorOptions = ["#7c3aed", "#db2777", "#ea580c", "#16a34a", "#0891b2", "#ca8a04"]
    private let emojiOptions = ["🏋️", "💪", "🔥", "⚡", "🎯", "🦾", "🚀", "🏆"]

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
            .navigationTitle(mode == .create ? "Profil erstellen" : "Willkommen zurück!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .create ? "Erstellen" : "Einloggen") {
                        Task { await submit() }
                    }
                    .disabled(isLoading || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showRecoveryCode) {
                RecoveryCodeSheet(code: createdRecoveryCode) {
                    showRecoveryCode = false
                    dismiss()
                }
            }
        }
    }

    private var createSection: some View {
        Group {
            Section("Dein Name") {
                TextField("Name eingeben…", text: $name)
            }
            Section("Avatar") {
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
            Section("Farbe") {
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
                    Button("Bereits registriert? Einloggen →") {
                        withAnimation { mode = .login }
                    }
                    .foregroundColor(K.accentDark)
                }
            }
        }
    }

    private var loginSection: some View {
        Group {
            Section("Dein Name") {
                TextField("Name eingeben…", text: $name)
            }
            Section("Recovery Code") {
                SecureField("XXXX-XXXX-XXXX", text: $recoveryCode)
                    .textInputAutocapitalization(.characters)
            }
            Section {
                Button("Neu hier? Profil erstellen →") {
                    withAnimation { mode = .create }
                }
                .foregroundColor(K.accentDark)
            }
        }
    }

    private func submit() async {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { error = "Bitte Namen eingeben."; return }
        isLoading = true; error = ""
        do {
            if mode == .create {
                let resp = try await APIClient.shared.registerUser(
                    groupId: group.id, name: n, avatarEmoji: emoji, avatarColor: color)
                let profile = UserProfile(userId: resp.userId, name: resp.name,
                                         avatarEmoji: resp.avatarEmoji, avatarColor: resp.avatarColor,
                                         avatarImg: resp.avatarImg, recoveryCode: resp.recoveryCode,
                                         isCreator: resp.isCreator)
                createdRecoveryCode = resp.recoveryCode
                await appState.enterGroup(group, profile: profile)
                showRecoveryCode = true
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
            error = "Dieser Name ist bereits vergeben."
        } catch APIError.unauthorized {
            error = "Falscher Recovery Code."
        } catch APIError.notFound {
            error = "Nutzer nicht gefunden."
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
                Text("Recovery Code sichern!")
                    .font(.title2.bold())
                Text("Ohne diesen Code kannst du dich auf neuen Geräten nicht einloggen.")
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
                    Label(copied ? "Kopiert ✓" : "Code kopieren", systemImage: "doc.on.doc")
                        .accentButton()
                }
                .padding(.horizontal)

                Button("Ich hab's gespeichert! →") {
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
