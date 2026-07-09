import SwiftUI

struct GroupSwitcherSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showJoin = false
    @State private var showCreate = false

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
                                Text(K.L.mgsActive)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(K.accentDark)
                            } else {
                                Text(K.L.mgsSwitch)
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
                        Label(K.L.mgsJoin, systemImage: "link")
                            .foregroundColor(K.accentDark)
                    }
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showCreate = true
                        }
                    } label: {
                        Label(K.L.mgsCreate, systemImage: "plus.circle")
                            .foregroundColor(K.accentDark)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GymBackground())
            .navigationTitle(K.L.mgsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(K.L.close) { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showJoin) { JoinGroupSheet() }
        .sheet(isPresented: $showCreate) { CreateGroupSheet() }
    }
}
