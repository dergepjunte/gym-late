import SwiftUI

/// Admin login (website: #modal-admin) — password is verified server-side
/// via POST /api/admin/verify and kept in memory only, never persisted.
struct AdminLoginSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Binding var toast: String?

    @State private var password = ""
    @State private var error = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section(K.L.maLbl) {
                    SecureField(K.L.maLbl, text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if !error.isEmpty {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GymBackground())
            .navigationTitle(K.L.maTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(K.L.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(K.L.maSubmit) { Task { await login() } }
                        .disabled(isLoading || password.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func login() async {
        isLoading = true; error = ""
        let ok = (try? await APIClient.shared.verifyAdmin(password: password)) ?? false
        if ok {
            appState.adminPassword = password
            toast = K.L.toastAdmIn
            hapticSuccess()
            dismiss()
        } else {
            error = K.L.maError
        }
        isLoading = false
    }
}
