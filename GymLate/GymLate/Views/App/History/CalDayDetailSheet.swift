import SwiftUI

// MARK: - Day detail sheet (website: #modal-cal-day)

struct CalDayDetailSheet: View {
    let date: String
    var entries: [Entry]
    var people: [Person] = []
    var adminMode: Bool = false
    @Binding var toast: String?

    @EnvironmentObject var appState: AppState
    @Environment(\.pageDismiss) private var dismiss

    // Admin: add entry form
    @State private var showAddForm = false
    @State private var addPerson = ""
    @State private var addType: EntryType = .attend
    @State private var addMins = 5
    @State private var isAdding = false

    // Admin: editing an existing entry
    @State private var editingEntry: Entry?
    @State private var editType: EntryType = .attend
    @State private var editMins = 5
    @State private var isEditing = false

    // Live entries (refreshed after each admin op)
    @State private var liveEntries: [Entry] = []

    private enum EntryType: String, CaseIterable {
        case attend, late, skip
        var label: String {
            switch self {
            case .attend: return K.L.mlModeAttend
            case .late:   return K.L.mlModeLate
            case .skip:   return K.L.mlModeSkip
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    let displayed = liveEntries.isEmpty && entries.isEmpty ? [] : (!liveEntries.isEmpty ? liveEntries : entries)

                    ForEach(displayed) { e in
                        entryRow(e)
                    }

                    if displayed.isEmpty {
                        Text(K.L.de ? "Keine Einträge für diesen Tag." : "No entries for this day.")
                            .font(Theme.body(14)).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }

                    // Admin: add entry form
                    if adminMode {
                        if showAddForm {
                            addEntryForm
                        } else {
                            Button {
                                addPerson = people.first?.name ?? ""
                                showAddForm = true
                            } label: {
                                Label(K.L.admCalAddEntry, systemImage: "plus.circle.fill")
                                    .font(Theme.body(14, .semibold))
                                    .foregroundColor(K.accentDark)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(16)
            }
            .background(GymBackground())
            .navigationTitle(fmtFull(date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .onAppear { liveEntries = entries }
        }
    }

    @ViewBuilder
    private func entryRow(_ e: Entry) -> some View {
        HStack(spacing: 12) {
            if let p = people.first(where: { $0.name.lowercased() == e.person.lowercased() }) {
                AvatarView(emoji: p.avatarEmoji, color: p.avatarColor, img: p.avatarImg, size: 38)
            } else {
                Text(initials(e.person))
                    .font(Theme.body(13, .bold)).foregroundColor(K.onAccent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(LinearGradient(
                        colors: Theme.accentGradient, startPoint: .topLeading, endPoint: .bottomTrailing)))
            }
            Text(e.person).font(Theme.body(15, .semibold))
            Spacer()

            // Admin edit / delete inline controls
            if adminMode {
                if editingEntry?.id == e.id {
                    // Inline edit row
                    HStack(spacing: 8) {
                        Picker("", selection: $editType) {
                            ForEach(EntryType.allCases, id: \.self) { t in
                                Text(t.rawValue.prefix(1).uppercased()).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)

                        if editType == .late {
                            Stepper("\(editMins)", value: $editMins, in: 1...999)
                                .labelsHidden()
                                .font(Theme.body(12))
                        }

                        Button { Task { await commitEdit(e) } } label: {
                            Image(systemName: isEditing ? "ellipsis" : "checkmark")
                                .foregroundColor(K.green)
                        }
                        .buttonStyle(.plain)

                        Button { editingEntry = nil } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    HStack(spacing: 10) {
                        EntryBadge(entry: e)
                        Button {
                            editingEntry = e
                            editType = EntryType(rawValue: e.type) ?? .attend
                            editMins = e.mins > 0 ? e.mins : 5
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 13))
                                .foregroundColor(K.amberText)
                        }
                        .buttonStyle(.plain)
                        Button { Task { await deleteEntry(e) } } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundColor(K.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                EntryBadge(entry: e)
            }
        }
        .padding(12)
        .glassCard(radius: 14)
    }

    private var addEntryForm: some View {
        VStack(spacing: 12) {
            // Person picker
            Picker(K.L.mlLblPerson, selection: $addPerson) {
                ForEach(people, id: \.id) { p in Text(p.name).tag(p.name) }
            }
            .pickerStyle(.menu)

            // Type segmented
            Picker("", selection: $addType) {
                ForEach(EntryType.allCases, id: \.self) { t in
                    Text(t.label).tag(t)
                }
            }
            .pickerStyle(.segmented)

            // Minutes (late only)
            if addType == .late {
                Stepper("\(addMins) \(K.L.minsShort)", value: $addMins, in: 1...999)
                    .font(Theme.body(14))
            }

            HStack(spacing: 12) {
                Button(K.L.cancel) {
                    showAddForm = false
                }
                .font(Theme.body(14))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.systemFill).clipShape(Capsule()))

                Button { Task { await addEntry() } } label: {
                    Text(isAdding ? "…" : K.L.save)
                        .font(Theme.body(14, .bold))
                        .foregroundColor(K.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(K.accentDeep.clipShape(Capsule()))
                }
                .disabled(isAdding || addPerson.isEmpty)
            }
        }
        .padding(14)
        .glassCard(radius: 14)
        .padding(.top, 8)
    }

    // MARK: Admin ops

    private func addEntry() async {
        guard let group = appState.activeGroup, !addPerson.isEmpty else { return }
        isAdding = true
        do {
            let mins = addType == .late ? addMins : 0
            _ = try await APIClient.shared.logEntry(
                groupId: group.id, person: addPerson, date: date,
                type: addType.rawValue, mins: addType == .late ? mins : nil)
            await appState.refreshData()
            liveEntries = appState.groupData?.entries.filter { $0.date == date } ?? []
            showAddForm = false
            toast = K.L.toastEntryAdded
            hapticSuccess()
        } catch {
            toast = K.L.errServer
        }
        isAdding = false
    }

    private func commitEdit(_ e: Entry) async {
        guard let group = appState.activeGroup,
              let pw = appState.adminPassword else { return }
        isEditing = true
        do {
            let mins = editType == .late ? editMins : nil
            try await APIClient.shared.patchEntry(
                groupId: group.id, entryId: e.id,
                type: editType.rawValue, date: date,
                mins: mins, adminPassword: pw)
            await appState.refreshData()
            liveEntries = appState.groupData?.entries.filter { $0.date == date } ?? []
            editingEntry = nil
            toast = K.L.toastEntryEdited
            hapticSuccess()
        } catch {
            toast = K.L.errServer
        }
        isEditing = false
    }

    private func deleteEntry(_ e: Entry) async {
        guard let group = appState.activeGroup,
              let pw = appState.adminPassword else { return }
        do {
            try await APIClient.shared.deleteEntry(
                groupId: group.id, entryId: e.id, adminPassword: pw)
            await appState.refreshData()
            liveEntries = appState.groupData?.entries.filter { $0.date == date } ?? []
            toast = K.L.toastEntryDeleted
            hapticSuccess()
        } catch {
            toast = K.L.errServer
        }
    }
}
