import SwiftUI

struct LogEntrySheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.pageDismiss) var dismiss
    @Binding var toast: String?

    @State private var mode: EntryMode = .attend
    @State private var selectedPerson: String = ""
    @State private var date = dateYMD(Date())
    @State private var mins = 5
    @State private var selectedReason = ""
    @State private var isLoading = false
    @State private var error = ""

    enum EntryMode: CaseIterable {
        case attend, late, skip

        var label: String {
            switch self {
            case .attend: return K.L.mlModeAttend
            case .late:   return K.L.mlModeLate
            case .skip:   return K.L.mlModeSkip
            }
        }
    }

    private var people: [Person] {
        appState.groupData?.people ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                // Mode picker
                Section {
                    Picker("", selection: $mode) {
                        ForEach(EntryMode.allCases, id: \.self) { m in
                            Text(m.label).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                // Person
                Section(K.L.mlLblPerson) {
                    if people.isEmpty {
                        Text(K.L.noPeople).foregroundColor(.secondary)
                    } else {
                        Picker(K.L.mlLblPerson, selection: $selectedPerson) {
                            Text(K.L.de ? "Wählen…" : "Choose…").tag("")
                            ForEach(people, id: \.id) { p in
                                Text(p.name).tag(p.name)
                            }
                        }
                    }
                }

                // Date
                Section(K.L.mlLblDate) {
                    DatePicker(K.L.mlLblDate, selection: Binding(
                        get: { parseDate(date) ?? Date() },
                        set: { date = dateYMD($0) }
                    ), displayedComponents: .date)
                    .labelsHidden()
                }

                // Mode-specific fields
                if mode == .late {
                    Section(K.L.mlLblMins) {
                        Stepper("\(mins) \(K.L.minsShort)", value: $mins, in: 1...999)
                    }
                }
                if mode == .skip {
                    Section(K.L.mlLblReason) {
                        Picker(K.L.mlLblReason, selection: $selectedReason) {
                            Text(K.L.de ? "Kein Grund" : "No reason").tag("")
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
            .navigationTitle(K.L.mlTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(K.L.save) { Task { await save() } }
                        .disabled(isLoading || selectedPerson.isEmpty)
                }
            }
            .onAppear {
                // Pre-select self
                if let profile = appState.userProfile { selectedPerson = profile.name }
            }
        }
    }

    /// Save + check-in ceremony — mirrors the website's ml-save handler:
    /// a self/today attend inside the fixed-time window may become a late
    /// entry, then late-anim → streak-anim → chest → toast chain.
    private func save() async {
        guard appState.activeGroup != nil, !selectedPerson.isEmpty else { return }
        isLoading = true; error = ""
        let isSelfToday = selectedPerson == appState.userProfile?.name && date == dateYMD(Date())
        let wasExtended = appState.myStreakInfo()?.extendedToday ?? false
        do {
            switch mode {
            case .attend:
                let lateness = isSelfToday ? appState.computeCheckinLateness() : nil
                let result = try await appState.logEntry(
                    person: selectedPerson, date: date,
                    type: (lateness?.isLate == true) ? "late" : "attend",
                    mins: (lateness?.isLate == true) ? lateness?.minsOff : nil)
                dismiss()
                switch result {
                case .synced(let resp):
                    if isSelfToday {
                        appState.runCheckinCeremony(chest: resp.chest, wasExtended: wasExtended,
                                                    lateness: lateness) { toast = $0 }
                    } else {
                        toast = K.L.toastAttendSaved
                        if let chest = resp.chest { appState.chestResult = chest }
                    }
                case .queued:
                    toast = K.L.toastQueuedOffline
                }
            case .late:
                let result = try await appState.logEntry(
                    person: selectedPerson, date: date, type: "late", mins: mins)
                dismiss()
                if case .queued = result {
                    toast = K.L.toastQueuedOffline
                } else if isSelfToday, !wasExtended, let info = appState.myStreakInfo() {
                    appState.streakAnimStreak = info.streak
                } else {
                    toast = K.L.toastSaved
                }
            case .skip:
                let result = try await appState.logEntry(
                    person: selectedPerson, date: date, type: "skip",
                    reason: selectedReason.isEmpty ? nil : selectedReason)
                dismiss()
                toast = { if case .queued = result { return K.L.toastQueuedOffline }
                          return K.L.toastSkipSaved }()
            }
            hapticSuccess()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
