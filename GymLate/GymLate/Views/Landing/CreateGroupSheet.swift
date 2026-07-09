import SwiftUI

struct CreateGroupSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var groupName = ""
    @State private var gymDays = Array(repeating: true, count: 7)
    @State private var isLoading = false
    @State private var error = ""
    @State private var createdGroup: GroupInfo?
    @State private var showProfile = false

    let dayLabels = K.L.dayNames

    var body: some View {
        NavigationStack {
            Form {
                Section(K.L.de ? "Gruppenname" : "Group Name") {
                    TextField(K.L.de ? "z.B. Montag-Crew" : "e.g. Monday Crew", text: $groupName)
                }
                Section(K.L.de ? "Gym-Tage" : "Gym days") {
                    HStack {
                        ForEach(0..<7) { i in
                            Button {
                                gymDays[i].toggle()
                            } label: {
                                Text(dayLabels[i])
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 36, height: 36)
                                    .background(gymDays[i] ? K.accent : Color(.secondarySystemFill))
                                    .foregroundColor(gymDays[i] ? K.onAccent : .secondary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                if !error.isEmpty {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GymBackground())
            .navigationTitle(K.L.de ? "Neue Gruppe" : "New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(K.L.de ? "Erstellen" : "Create") { Task { await create() } }
                        .disabled(isLoading || groupName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .fullScreenCover(isPresented: $showProfile) {
                if let g = createdGroup {
                    ProfileSetupSheet(group: g, isNew: true)
                }
            }
        }
    }

    private func create() async {
        let name = groupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { error = K.L.errServer; return }
        guard gymDays.contains(true) else { error = K.L.errAtLeastOneDay; return }
        let mask = gymDays.map { $0 ? "1" : "0" }.joined()
        isLoading = true
        do {
            let g = try await APIClient.shared.createGroup(name: name, gymDays: mask)
            createdGroup = g
            showProfile = true
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
