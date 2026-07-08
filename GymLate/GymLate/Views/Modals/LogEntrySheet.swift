import SwiftUI

struct LogEntrySheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Binding var toast: String?

    @State private var mode: EntryMode = .attend
    @State private var selectedPerson: String = ""
    @State private var date = dateYMD(Date())
    @State private var mins = 5
    @State private var selectedReason = ""
    @State private var isLoading = false
    @State private var error = ""

    enum EntryMode: String, CaseIterable {
        case attend = "✓ Eingecheckt"
        case late   = "⏱ Verspätet"
        case skip   = "⊘ Skip"
    }

    private var people: [Person] {
        appState.groupData?.people ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                // Mode picker
                Section {
                    Picker("Modus", selection: $mode) {
                        ForEach(EntryMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                // Person
                Section("Person") {
                    if people.isEmpty {
                        Text("Erst Personen hinzufügen!").foregroundColor(.secondary)
                    } else {
                        Picker("Person", selection: $selectedPerson) {
                            Text("Wählen…").tag("")
                            ForEach(people, id: \.id) { p in
                                Text(p.name).tag(p.name)
                            }
                        }
                    }
                }

                // Date
                Section("Datum") {
                    DatePicker("Datum", selection: Binding(
                        get: { parseDate(date) ?? Date() },
                        set: { date = dateYMD($0) }
                    ), displayedComponents: .date)
                    .labelsHidden()
                }

                // Mode-specific fields
                if mode == .late {
                    Section("Minuten zu spät") {
                        Stepper("\(mins) Min.", value: $mins, in: 1...999)
                    }
                }
                if mode == .skip {
                    Section("Grund (optional)") {
                        Picker("Grund", selection: $selectedReason) {
                            Text("Kein Grund").tag("")
                            ForEach(K.L.reasons, id: \.id) { r in
                                Text(r.label).tag(r.id)
                            }
                        }
                    }
                }

                if !error.isEmpty {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GymBackground())
            .navigationTitle("Eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { Task { await save() } }
                        .disabled(isLoading || selectedPerson.isEmpty)
                }
            }
            .onAppear {
                // Pre-select self
                if let profile = appState.userProfile { selectedPerson = profile.name }
            }
        }
    }

    private func save() async {
        guard appState.activeGroup != nil, !selectedPerson.isEmpty else { return }
        isLoading = true; error = ""
        do {
            let result = try await appState.logEntry(
                person: selectedPerson,
                date: date,
                type: mode == .attend ? "attend" : mode == .late ? "late" : "skip",
                mins: mode == .late ? mins : nil,
                reason: mode == .skip && !selectedReason.isEmpty ? selectedReason : nil)
            switch result {
            case .synced(let resp):
                switch mode {
                case .attend:
                    if let chest = resp.chest, chest.got_freeze {
                        toast = "❄️ Freeze erhalten! Streak: 🔥 \(chest.streak)"
                    } else {
                        toast = "Eingecheckt ✓"
                    }
                case .late:
                    toast = K.L.toastSaved
                case .skip:
                    toast = "Skip gespeichert ⊘"
                }
            case .queued:
                toast = "Offline gespeichert – wird synchronisiert ✓"
            }
            hapticSuccess()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
