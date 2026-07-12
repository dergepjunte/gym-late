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
                VStack(spacing: 0) {
                    AppHeader(toast: $toast)
                    VStack(spacing: 14) {
                        calNav
                        weekdayHeader
                        monthGrid
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                }
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
                let hasEntry = info[dateStr] != nil
                let sched = dayScheduled(dateStr, mask: mask)
                dayCell(day: day, dateStr: dateStr, info: info[dateStr],
                        isToday: dateStr == today,
                        missed: !hasEntry && dateStr < today && sched,
                        rest:   !hasEntry && !sched)
            }
        }
    }

    @ViewBuilder
    private func dayCell(day: Int, dateStr: String, info: DayInfo?, isToday: Bool, missed: Bool, rest: Bool = false) -> some View {
        // Same coloring rules as the website's renderCalendar()
        let isPastOrToday = dateStr <= dateYMD(Date())
        let restPast = rest && isPastOrToday
        let bg: Color? = {
            if restPast { return Color.secondary.opacity(0.10) }
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
                    .foregroundColor(restPast ? .secondary : (isToday ? K.amberText : .primary))
                    .strikethrough(restPast, color: .secondary)
                    .opacity(restPast ? 0.6 : 1)
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
                    } else if rest && !isPastOrToday {
                        // Future rest day: small muted dash
                        Text("–").font(Theme.body(10)).foregroundColor(.secondary.opacity(0.4))
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

private func firstOfMonth(_ d: Date) -> Date {
    let cal = Calendar.iso8601UTC
    return cal.date(from: cal.dateComponents([.year, .month], from: d))!
}
