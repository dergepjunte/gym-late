import SwiftUI

struct JoinGroupSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.pageDismiss) var dismiss
    @State private var code = ""
    @State private var isLoading = false
    @State private var error = ""
    @State private var foundGroup: GroupInfo?
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("XXXXXX", text: $code)
                        .textInputAutocapitalization(.characters)
                        .keyboardType(.asciiCapable)
                        .onChange(of: code) { code = String($0.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6)) }
                } header: {
                    Text("6-stelliger Gruppencode")
                } footer: {
                    Text(K.L.de ? "Den Code bekommst du von jemandem der Gruppe." : "Get the code from someone in the group.")
                }
                if !error.isEmpty {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GymBackground())
            .navigationTitle(K.L.de ? "Gruppe beitreten" : "Join Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(K.L.de ? "Beitreten" : "Join") { Task { await join() } }
                        .disabled(isLoading || code.count < 6)
                }
            }
            .fullPageCover(isPresented: $showProfile) {
                if let g = foundGroup {
                    ProfileSetupSheet(group: g, isNew: false)
                }
            }
            // Collapse the whole landing cover chain once login succeeds so
            // no stale NavigationStack back-chevrons remain visible.
            .onChange(of: appState.activeGroup?.id) { _, id in
                guard id != nil else { return }
                // Small delay so RecoveryCodeSheet (create-new flow) can appear
                // before JoinGroupSheet tears down.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    dismiss()
                }
            }
        }
    }

    private func join() async {
        guard code.count == 6 else { error = K.L.de ? "Code muss 6 Zeichen haben." : "Code must be 6 characters."; return }
        isLoading = true
        do {
            let g = try await APIClient.shared.joinGroup(code: code)
            foundGroup = g
            showProfile = true
        } catch APIError.notFound {
            error = K.L.errNotFound
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
