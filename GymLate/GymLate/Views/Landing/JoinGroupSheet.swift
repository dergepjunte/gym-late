import SwiftUI

struct JoinGroupSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
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
                    Text("Den Code bekommst du von jemandem der Gruppe.")
                }
                if !error.isEmpty {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GymBackground())
            .navigationTitle("Gruppe beitreten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Beitreten") { Task { await join() } }
                        .disabled(isLoading || code.count < 6)
                }
            }
            .sheet(isPresented: $showProfile) {
                if let g = foundGroup {
                    ProfileSetupSheet(group: g, isNew: false)
                }
            }
        }
    }

    private func join() async {
        guard code.count == 6 else { error = "Code muss 6 Zeichen haben."; return }
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
