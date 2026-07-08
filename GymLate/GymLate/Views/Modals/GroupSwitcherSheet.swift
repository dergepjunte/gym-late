import SwiftUI

struct GroupSwitcherSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showJoin = false

    private var allGroups: [GroupInfo] { LocalStore.shared.allGroups }

    var body: some View {
        NavigationStack {
            List {
                ForEach(allGroups) { g in
                    Button {
                        dismiss()
                        if g.id != appState.activeGroup?.id {
                            Task { await appState.switchGroup(g) }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text("🏋️").font(.system(size: 24))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.name).font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(g.code)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if g.id == appState.activeGroup?.id {
                                Text("Aktiv")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(K.accentDark)
                            } else {
                                Text("Wechseln")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showJoin = true
                        }
                    } label: {
                        Label("Einer anderen Gruppe beitreten", systemImage: "link")
                            .foregroundColor(K.accentDark)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GymBackground())
            .navigationTitle("Meine Gruppen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showJoin) { JoinGroupSheet() }
    }
}
