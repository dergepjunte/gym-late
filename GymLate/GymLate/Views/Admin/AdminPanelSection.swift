import SwiftUI

/// Admin panel in the People tab (website: #admin-panel) — test data,
/// Wrapped replay, current-week toggle, overlay debug tools, exit.
struct AdminPanelSection: View {
    @EnvironmentObject var appState: AppState
    @Binding var toast: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(K.L.admTitle).eyebrow()
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                adminButton(K.L.admAdd, color: K.green) { Task { await addTestData() } }
                adminButton(appState.adminShowCurrentWeek ? K.L.admWeekOff : K.L.admWeekOn,
                            color: K.amberText) {
                    appState.adminShowCurrentWeek.toggle()
                }
                adminButton(K.L.admReplay, color: K.accentDeep) { appState.replayWrapped() }

                Divider().padding(.vertical, 2)

                adminButton(K.L.admForceHype, color: K.green) { appState.forceDailyHype() }
                adminButton(K.L.admForceGeo, color: Color(hex: "#0891b2")) { appState.forceGeoPrompt() }
                adminButton(K.L.admClearFlags, color: K.gold) {
                    appState.clearTodayFlags()
                    toast = "✓"
                }

                Divider().padding(.vertical, 2)

                adminButton(K.L.admExit, color: K.red) {
                    appState.adminPassword = nil
                    toast = K.L.toastAdmOut
                }
            }
            .padding(12)
            .glassCard()
        }
    }

    private func adminButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
            haptic(.light)
        } label: {
            Text(label)
                .font(Theme.body(13, .bold))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(color.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Website adm-add-btn: seed last week's test entries for existing members.
    private func addTestData() async {
        guard let group = appState.activeGroup,
              let people = appState.groupData?.people, !people.isEmpty else {
            toast = K.L.noPeople
            return
        }
        let cal = Calendar.iso8601UTC
        let lastMon = cal.date(byAdding: .weekOfYear, value: -1, to: cal.startOfWeek(for: Date()))!
        do {
            for person in people.prefix(4) {
                let day = cal.date(byAdding: .day, value: Int.random(in: 0...5), to: lastMon)!
                let kind = ["late", "late", "attend", "skip"].randomElement()!
                _ = try await APIClient.shared.logEntry(
                    groupId: group.id, person: person.name, date: dateYMD(day),
                    type: kind, mins: kind == "late" ? Int.random(in: 5...45) : nil,
                    reason: kind == "skip" ? "rest" : nil)
            }
            await appState.refreshData()
            toast = K.L.toastAdded
        } catch {
            toast = K.L.errServer
        }
    }
}

/// Admin member editor (website: #modal-admin-user) — streak, freezes,
/// available days without the 30-day lock.
struct AdminUserEditSheet: View {
    let person: Person
    @Binding var toast: String?
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var streak: Int
    @State private var freezes: Int
    @State private var availDays: [Bool]
    @State private var error = ""
    @State private var isLoading = false

    init(person: Person, toast: Binding<String?>) {
        self.person = person
        _toast = toast
        _streak = State(initialValue: person.streak)
        _freezes = State(initialValue: person.freezes)
        let mask = person.availDays ?? "1111111"
        _availDays = State(initialValue: mask.count == 7 ? mask.map { $0 == "1" } : Array(repeating: true, count: 7))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(K.L.auDaysLbl) {
                    HStack {
                        ForEach(0..<7, id: \.self) { i in
                            Button { availDays[i].toggle() } label: {
                                Text(K.L.dayNames[i])
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 36, height: 36)
                                    .background(availDays[i] ? K.accent : Color(.secondarySystemFill))
                                    .foregroundColor(availDays[i] ? K.onAccent : .secondary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                Section {
                    Stepper("\(K.L.streak): \(streak)", value: $streak, in: 0...9999)
                    Stepper("\(K.L.freezes): \(freezes)", value: $freezes, in: 0...10)
                }
                if !error.isEmpty {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GymBackground())
            .navigationTitle(K.L.auTitle(person.name))
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
        isLoading = true
        do {
            try await APIClient.shared.patchUser(
                groupId: group.id, userId: person.id,
                availDays: availDays.map { $0 ? "1" : "0" }.joined(),
                streak: streak, freezes: freezes, adminPassword: pw)
            await appState.refreshData()
            toast = K.L.toastMemberUpdated
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
