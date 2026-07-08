import SwiftUI
import MapKit

struct SettingsSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var gymDays = Array(repeating: true, count: 7)
    @State private var availDays: [Bool]? = nil
    @State private var isLoading = false
    @State private var toast: String?
    @State private var error = ""

    private let dayLabels = K.L.dayNames

    var body: some View {
        NavigationStack {
            Form {
                // Gym days (group, creator only)
                if appState.userProfile?.isCreator == true {
                    Section {
                        HStack {
                            ForEach(0..<7) { i in
                                Button { gymDays[i].toggle() } label: {
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
                        Button("Gym-Tage speichern") { Task { await saveGymDays() } }
                            .foregroundColor(K.accentDark)
                    } header: { Text("Gym-Tage der Gruppe") }
                }

                // My available days
                Section {
                    HStack {
                        ForEach(0..<7) { i in
                            Button {
                                if availDays == nil { availDays = Array(repeating: true, count: 7) }
                                availDays![i].toggle()
                            } label: {
                                let on = availDays?[i] ?? true
                                Text(dayLabels[i])
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 36, height: 36)
                                    .background(on ? K.accentLight : Color(.secondarySystemFill))
                                    .foregroundColor(on ? K.onAccent : .secondary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Button("Meine Tage speichern") { Task { await saveAvailDays() } }
                        .foregroundColor(K.accentDark)
                } header: { Text("Meine verfügbaren Tage") }

                // Leave group
                Section {
                    Button("Gruppe verlassen", role: .destructive) {
                        appState.leaveCurrentGroup()
                        dismiss()
                    }
                }

                if !error.isEmpty {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GymBackground())
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .onAppear { loadCurrentValues() }
            .toast($toast)
        }
    }

    private func loadCurrentValues() {
        if let data = appState.groupData {
            gymDays = data.gymDays.map { $0 == "1" }
        }
        if let profile = appState.userProfile,
           let data = appState.groupData,
           let me = data.people.first(where: { $0.id == profile.userId }),
           let ad = me.availDays {
            availDays = ad.map { $0 == "1" }
        }
    }

    private func saveGymDays() async {
        guard gymDays.contains(true) else { error = "Mindestens 1 Tag wählen."; return }
        let mask = gymDays.map { $0 ? "1" : "0" }.joined()
        isLoading = true
        do {
            let synced = try await appState.saveGymDays(mask: mask)
            toast = synced ? "Gym-Tage gespeichert ✓" : "Gespeichert – wird synchronisiert ✓"
        } catch { self.error = error.localizedDescription }
        isLoading = false
    }

    private func saveAvailDays() async {
        let mask = (availDays ?? Array(repeating: true, count: 7)).map { $0 ? "1" : "0" }.joined()
        isLoading = true
        do {
            let synced = try await appState.saveAvailDays(mask: mask)
            toast = synced ? "Verfügbarkeit gespeichert ✓" : "Gespeichert – wird synchronisiert ✓"
        } catch {
            let desc = error.localizedDescription
            if desc.contains("avail_locked") {
                self.error = "Bitte warte, bevor du deine Tage erneut änderst."
            } else {
                self.error = desc
            }
        }
        isLoading = false
    }
}
