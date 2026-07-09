import SwiftUI

/// Admin-only entry editor (website: #modal-edit-entry) — change type, date,
/// minutes and skip reason of any entry via PATCH /entries/:eid.
struct EditEntrySheet: View {
    let entry: Entry
    @Binding var toast: String?
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var mode: String
    @State private var date: String
    @State private var mins: Int
    @State private var reason: String
    @State private var error = ""
    @State private var isLoading = false

    init(entry: Entry, toast: Binding<String?>) {
        self.entry = entry
        _toast = toast
        _mode = State(initialValue: entry.type)
        _date = State(initialValue: entry.date)
        _mins = State(initialValue: max(1, entry.mins))
        _reason = State(initialValue: entry.reason ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $mode) {
                        Text(K.L.mlModeAttend).tag("attend")
                        Text(K.L.mlModeLate).tag("late")
                        Text(K.L.mlModeSkip).tag("skip")
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                Section(K.L.mlLblDate) {
                    DatePicker("", selection: Binding(
                        get: { parseDate(date) ?? Date() },
                        set: { date = dateYMD($0) }
                    ), displayedComponents: .date)
                    .labelsHidden()
                }

                if mode == "late" {
                    Section(K.L.mlLblMins) {
                        Stepper("\(mins) \(K.L.minsShort)", value: $mins, in: 1...999)
                    }
                }
                if mode == "skip" {
                    Section(K.L.mlLblReason) {
                        Picker(K.L.mlLblReason, selection: $reason) {
                            Text("—").tag("")
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
            .navigationTitle(K.L.eeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(K.L.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(K.L.save) { Task { await save() } }.disabled(isLoading)
                }
            }
        }
    }

    private func save() async {
        guard let group = appState.activeGroup, let pw = appState.adminPassword else { return }
        isLoading = true; error = ""
        do {
            try await APIClient.shared.patchEntry(
                groupId: group.id, entryId: entry.id, type: mode, date: date,
                mins: mode == "late" ? mins : nil,
                reason: mode == "skip" && !reason.isEmpty ? reason : nil,
                adminPassword: pw)
            await appState.refreshData()
            toast = K.L.toastSaved
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
