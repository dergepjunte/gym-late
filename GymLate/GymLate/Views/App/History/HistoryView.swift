import SwiftUI

/// Verlauf tab — month calendar, mirrors the website's #pane-history:
/// ‹ month › nav, weekday header, colored day cells, day-detail sheet, FAB.
struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var monthAnchor: Date = firstOfMonth(Date())
    @State private var selectedDay: CalDay?
    @State private var showLogEntry = false
    @State private var toast: String?

    // Admin mode needs a toast binding for the CalDayDetailSheet
    @State private var adminToast: String?

    private struct DayInfo {
        var late = 0, attend = 0, skip = 0, mins = 0
    }

    struct CalDay: Identifiable {
        let id: String   // yyyy-MM-dd
        let entries: [Entry]
    }

    private var infoByDate: [String: DayInfo] {
        var map: [String: DayInfo] = [:]
        for e in appState.groupData?.entries ?? [] {
            var i = map[e.date] ?? DayInfo()
            switch e.type {
            case "attend": i.attend += 1
            case "skip":   i.skip += 1
            default:       i.late += 1; i.mins += e.mins
            }
            map[e.date] = i
        }
        return map
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 14) {
                    calNav
                    weekdayHeader
                    monthGrid
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // FAB — the website shows it on the history tab too
            Button {
                showLogEntry = true
                haptic(.medium)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(K.onAccent)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle().fill(LinearGradient(colors: Theme.accentGradient,
                                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .shadow(color: K.accentDeep.opacity(0.4), radius: 12, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 16)
        }
        .fullPageCover(item: $selectedDay) { day in
            CalDayDetailSheet(date: day.id, entries: day.entries,
                              people: appState.groupData?.people ?? [],
                              adminMode: appState.adminMode,
                              toast: $adminToast)
        }
        .fullPageCover(isPresented: $showLogEntry) { LogEntrySheet(toast: $toast) }
        .onChange(of: adminToast) { _, v in if v != nil { toast = v; adminToast = nil } }
        .toast($toast)
    }

    // MARK: Month navigation

    private var calNav: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .light))
                    .padding(.horizontal, 16).padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(monthLabel)
                .font(Theme.heading(18))
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .light))
                    .padding(.horizontal, 16).padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return f.string(from: monthAnchor)
    }

    private func shiftMonth(_ delta: Int) {
        monthAnchor = Calendar.iso8601UTC.date(byAdding: .month, value: delta, to: monthAnchor)!
        haptic(.light)
    }

    // MARK: Grid

    private var weekdayHeader: some View {
        HStack(spacing: 6) {
            ForEach(K.L.dayNames, id: \.self) { d in
                Text(String(d.prefix(1)))
                    .font(Theme.body(12, .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let cal = Calendar.iso8601UTC
        let daysInMonth = cal.range(of: .day, in: .month, for: monthAnchor)!.count
        let firstIdx = isoWeekdayIndex(dateYMD(monthAnchor))
        let today = dateYMD(Date())
        let info = infoByDate
        let mask = appState.groupData?.gymDays ?? "0000000"
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        return LazyVGrid(columns: cols, spacing: 6) {
            ForEach(0..<firstIdx, id: \.self) { _ in Color.clear.frame(height: 52) }
            ForEach(1...daysInMonth, id: \.self) { day in
                let dateStr = dateYMD(cal.date(byAdding: .day, value: day - 1, to: monthAnchor)!)
                dayCell(day: day, dateStr: dateStr, info: info[dateStr],
                        isToday: dateStr == today,
                        missed: info[dateStr] == nil && dateStr < today && dayScheduled(dateStr, mask: mask))
            }
        }
    }

    @ViewBuilder
    private func dayCell(day: Int, dateStr: String, info: DayInfo?, isToday: Bool, missed: Bool) -> some View {
        // Same coloring rules as the website's renderCalendar()
        let bg: Color? = {
            guard let i = info else { return nil }
            if i.late > 0 {
                let alpha = min(0.48, 0.12 + Double(i.late) * 0.09 + Double(i.mins) * 0.002)
                return Color(red: 239/255, green: 68/255, blue: 68/255).opacity(alpha)
            }
            if i.attend > 0 { return Color(red: 34/255, green: 197/255, blue: 94/255).opacity(0.18) }
            if i.skip > 0 { return Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.18) }
            return nil
        }()

        Button {
            let entries = appState.groupData?.entries.filter({ $0.date == dateStr }) ?? []
            // In admin mode, allow tapping any day (even empty) to add entries.
            // In normal mode, only days with entries are tappable.
            guard !entries.isEmpty || appState.adminMode else { return }
            selectedDay = CalDay(id: dateStr, entries: entries)
            haptic(.light)
        } label: {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(Theme.body(14, isToday ? .bold : .regular))
                    .foregroundColor(isToday ? K.amberText : .primary)
                Group {
                    if let i = info {
                        if i.late > 0 {
                            Text("\(i.late)").font(Theme.body(10, .bold)).foregroundColor(K.red)
                        } else if i.attend > 0 {
                            Text("✓").font(Theme.body(10, .bold)).foregroundColor(K.green)
                        } else {
                            Text("⊘").font(Theme.body(10, .bold)).foregroundColor(K.gold)
                        }
                    } else if missed {
                        Text("·").font(Theme.body(12, .bold)).foregroundColor(.secondary)
                    } else {
                        Text(" ").font(Theme.body(10))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(bg ?? .clear))
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(K.accent, lineWidth: 1.5)
                }
            }
            .overlay {
                if let i = info {
                    if i.late > 0 {
                        ZigzagBorder().stroke(K.red, lineWidth: 2.5)
                    } else if i.attend > 0 {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(K.green, lineWidth: 1.5)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel({
            if let i = info {
                if i.late > 0 { return K.L.de ? "Verspätet, \(i.late)×, \(i.mins) Min." : "Late, \(i.late) time\(i.late == 1 ? "" : "s"), \(i.mins) min" }
                if i.attend > 0 { return K.L.de ? "Pünktlich" : "On time" }
                if i.skip > 0 { return K.L.de ? "Übersprungen" : "Skipped" }
            }
            if missed { return K.L.de ? "Verpasst" : "Missed" }
            return "\(day)"
        }())
    }
}

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
                .background(Color(.systemFill).cornerRadius(10))

                Button { Task { await addEntry() } } label: {
                    Text(isAdding ? "…" : K.L.save)
                        .font(Theme.body(14, .bold))
                        .foregroundColor(K.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(K.accentDeep.cornerRadius(10))
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

/// Type badge shared with the week list — ✓ / "N Min." / ⊘ reason, like the web badges.
struct EntryBadge: View {
    let entry: Entry

    var body: some View {
        switch entry.type {
        case "attend":
            Text("✓")
                .font(Theme.body(13, .bold)).foregroundColor(K.green)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(K.green.opacity(0.14)))
        case "skip":
            Text("⊘ \(K.L.reasonLabel(entry.reason) ?? K.L.skipped)")
                .font(Theme.body(12, .bold)).foregroundColor(K.gold)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(K.gold.opacity(0.14)))
        default:
            Text("\(entry.mins) \(K.L.minsShort)")
                .font(Theme.body(13, .bold)).foregroundColor(K.red)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(K.red.opacity(0.14)))
        }
    }
}

private func firstOfMonth(_ d: Date) -> Date {
    let cal = Calendar.iso8601UTC
    return cal.date(from: cal.dateComponents([.year, .month], from: d))!
}
