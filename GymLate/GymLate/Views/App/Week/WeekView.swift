import SwiftUI

/// Woche tab — mirrors the website's #pane-week:
/// streak hero (grey/lit flame + check-in hint), fixed-time hero,
/// "Diese Woche" label, stat strip, skip chip, entry list.
struct WeekView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showLogEntry: Bool
    @Binding var toast: String?

    @State private var editingEntry: Entry?

    private var weekEntries: [Entry] {
        appState.groupData?.entriesThisWeek() ?? []
    }
    private var lateEntries: [Entry] { weekEntries.filter { $0.type == "late" } }
    private var skipEntries: [Entry] { weekEntries.filter { $0.type == "skip" } }
    private var totalMins: Int { lateEntries.reduce(0) { $0 + $1.mins } }

    /// Entries grouped by date, newest first.
    private var weekEntriesByDay: [(date: String, entries: [Entry])] {
        let grouped = Dictionary(grouping: weekEntries, by: { $0.date })
        return grouped.keys.sorted().reversed().map { (date: $0, entries: grouped[$0] ?? []) }
    }

    /// All 7 days of the current ISO week, newest first (Sunday → Monday).
    private var weekDates: [String] {
        let cal = Calendar.iso8601UTC
        let mon = cal.startOfWeek(for: Date())
        return (0..<7).map { i in dateYMD(cal.date(byAdding: .day, value: i, to: mon)!) }.reversed()
    }

    /// Effective schedule: group gymDays ∩ my availDays.
    private var myEffectiveMask: String {
        let gymDays = appState.groupData?.gymDays ?? "0000000"
        guard gymDays.count == 7 else { return gymDays }
        let myAvail = appState.groupData?.people.first(where: { $0.id == appState.userProfile?.userId })?.availDays
        guard let avail = myAvail, avail.count == 7 else { return gymDays }
        return String(zip(gymDays, avail).map { (g, a) in g == "1" && a == "1" ? Character("1") : Character("0") })
    }

    private func isRestDay(_ dateStr: String) -> Bool {
        let mask = myEffectiveMask
        guard mask.count == 7, let date = parseDate(dateStr) else { return false }
        let weekday = Calendar.iso8601UTC.component(.weekday, from: date) // 1=Sun
        let idx = weekday == 1 ? 6 : weekday - 2  // Mon=0..Sun=6
        guard idx >= 0 && idx < 7 else { return false }
        return mask[mask.index(mask.startIndex, offsetBy: idx)] == "0"
    }

    /// Days to show: days with entries + rest days (bit=0 in effective mask).
    private var visibleWeekDates: [String] {
        let entryDates = Set(weekEntriesByDay.map { $0.date })
        return weekDates.filter { entryDates.contains($0) || isRestDay($0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AppHeader(toast: $toast)

                VStack(spacing: 14) {
                // Streak hero — tap opens the check-in modal, like the website
                if let info = appState.myStreakInfo() {
                    StreakHero(streak: info.streak, extendedToday: info.extendedToday) {
                        showLogEntry = true
                        haptic(.medium)
                    }
                    .padding(.horizontal, 16)
                }

                // Fixed check-in time hero (beta)
                if let data = appState.groupData, data.fixedCheckinEnabled,
                   data.checkinTimeDate == dateYMD(Date()), let time = data.checkinTime {
                    CheckinTimeHero(time: time, toast: $toast)
                        .padding(.horizontal, 16)
                }

                // Section label + stat strip
                Text(K.L.lblWeek).eyebrow()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)

                HStack(spacing: 10) {
                    ScoreTile(value: lateEntries.count, label: K.L.sCountLbl,
                              hot: !lateEntries.isEmpty, color: K.red)
                    ScoreTile(value: totalMins, label: K.L.sMinLbl,
                              hot: totalMins > 0, color: K.accent)
                }
                .padding(.horizontal, 16)

                if !skipEntries.isEmpty {
                    Text("⊘ \(skipEntries.count) \(K.L.skipped)".uppercased())
                        .font(.system(size: 13, weight: .heavy).width(.condensed))
                        .tracking(1)
                        .foregroundColor(K.onAccent)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(K.accent))
                        .rotationEffect(.degrees(-2))
                }

                // Full week: entry blocks for days with entries, rest blocks for rest days.
                if visibleWeekDates.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(K.accent)
                        Text(K.L.emptyWeek)
                            .font(Theme.body(15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(visibleWeekDates, id: \.self) { date in
                            if let group = weekEntriesByDay.first(where: { $0.date == date }) {
                                VStack(spacing: 0) {
                                    Text(fmtFull(group.date))
                                        .eyebrow()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 14)
                                        .padding(.top, 10)
                                        .padding(.bottom, 4)
                                    ForEach(Array(group.entries.enumerated()), id: \.element.id) { idx, entry in
                                        if idx > 0 {
                                            Divider().padding(.leading, 66)
                                        }
                                        EntryRow(entry: entry,
                                                 people: appState.groupData?.people ?? [],
                                                 adminMode: appState.adminMode,
                                                 onEdit: { editingEntry = entry },
                                                 onDelete: { Task { await deleteEntry(entry) } },
                                                 standalone: false)
                                    }
                                }
                                .glassCard()
                            } else {
                                HStack(spacing: 12) {
                                    Image(systemName: "bed.double.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(fmtFull(date))
                                            .font(.system(size: 12, weight: .heavy).width(.condensed))
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                            .tracking(1.2)
                                        Text(K.L.restDay.uppercased())
                                            .font(Theme.heading(17))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    Spacer()
                                }
                                .padding(14)
                                .glassCard()
                                .opacity(0.55)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 20)
                }  // end inner VStack
                .padding(.top, 6)
            }  // end outer VStack
        }
        .sheet(item: $editingEntry) { e in
            EditEntrySheet(entry: e, toast: $toast)
        }
    }

    private func deleteEntry(_ entry: Entry) async {
        guard let group = appState.activeGroup, let pw = appState.adminPassword else { return }
        do {
            try await APIClient.shared.deleteEntry(groupId: group.id, entryId: entry.id,
                                                   adminPassword: pw)
            await appState.refreshData()
            haptic(.medium)
        } catch {
            toast = K.L.errServer
        }
    }
}

// MARK: - Streak Hero (website: #streak-hero, grey vs. lit flame)

struct StreakHero: View {
    let streak: Int
    let extendedToday: Bool
    let onTap: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var glowRadius: CGFloat = 14
    @State private var didAnimate = false
    @State private var pulse = false

    var body: some View {
        Button { onTap() } label: {
            VStack(spacing: 0) {
                // Hazard strip while today's session is still open; solid yellow once done.
                Group {
                    if extendedToday {
                        K.accent
                    } else {
                        HazardStripes(stripe: 9)
                    }
                }
                .frame(height: 7)

                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(extendedToday ? K.accent.opacity(0.16) : Color.white.opacity(0.04))
                            .frame(width: 74, height: 74)
                        Circle()
                            .strokeBorder(extendedToday ? K.accent.opacity(0.55) : Color.white.opacity(0.08),
                                          lineWidth: 2)
                            .frame(width: 74, height: 74)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(
                                extendedToday
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [K.accentLight, K.accent, Color(hex: "#ff7a00")],
                                    startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(Color.white.opacity(0.22)))
                            .shadow(color: extendedToday ? K.accent.opacity(0.7) : .clear, radius: glowRadius)
                            .scaleEffect(scale)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text("\(streak)")
                                .font(Theme.display(64))
                                .lineLimit(1)
                                .fixedSize()
                                .foregroundStyle(extendedToday
                                    ? AnyShapeStyle(LinearGradient(colors: Theme.accentGradient,
                                                                   startPoint: .top, endPoint: .bottom))
                                    : AnyShapeStyle(Color.white.opacity(0.85)))
                                .contentTransition(.numericText())
                            Text(K.L.shDays(streak).uppercased())
                                .font(.system(size: 15, weight: .heavy).width(.condensed))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 6) {
                        Image(systemName: extendedToday ? "checkmark.seal.fill" : "plus")
                            .font(.system(size: extendedToday ? 22 : 18, weight: .black))
                            .foregroundColor(extendedToday ? K.green : K.onAccent)
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(extendedToday ? K.green.opacity(0.15) : K.accent)
                            )
                            .scaleEffect(!extendedToday && pulse ? 1.07 : 1)
                        Text(extendedToday ? K.L.shHintDone : K.L.shHintOpen)
                            .font(.system(size: 11, weight: .bold).width(.condensed))
                            .textCase(.uppercase)
                            .foregroundColor(extendedToday ? K.green : K.amberText)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 110, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .glassCard(radius: 18)
        }
        .buttonStyle(SlabPress())
        .accessibilityLabel("\(streak) \(K.L.shDays(streak))\(extendedToday ? ", \(K.L.shHintDone)" : ", \(K.L.shHintOpen)")")
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .onChange(of: extendedToday) { _, newValue in
            guard newValue, !didAnimate, !UIAccessibility.isReduceMotionEnabled else { return }
            didAnimate = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scale = 1.25
                glowRadius = 30
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    scale = 1.0
                    glowRadius = 14
                }
            }
        }
    }
}

// MARK: - Scoreboard tile (week stats)

struct ScoreTile: View {
    let value: Int
    let label: String
    var hot: Bool
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(1.6)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(value)")
                .font(Theme.display(44))
                .foregroundColor(hot ? color : .white.opacity(0.85))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .ironCard(radius: 14, accent: hot ? color : K.iron3)
    }
}

// MARK: - Fixed check-in time hero (website: #checkin-time-hero)

struct CheckinTimeHero: View {
    let time: String
    @Binding var toast: String?
    @EnvironmentObject var appState: AppState

    @State private var editing = false
    @State private var pickedTime = Date()

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(K.accent)
            if editing {
                DatePicker("", selection: $pickedTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Button(K.L.save) { Task { await saveTime() } }
                    .font(Theme.body(13, .bold))
                    .foregroundColor(K.amberText)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(K.L.checkinTimeChipLbl)
                        .font(Theme.body(12)).foregroundColor(.secondary)
                    Text(time)
                        .font(Theme.display(30))
                        .foregroundColor(K.amberText)
                }
                Spacer()
                Button(K.L.checkinTimeChangeBtn) {
                    if let d = parseTimeHHMM(time) { pickedTime = d }
                    editing = true
                }
                .font(Theme.body(12, .bold))
                .foregroundColor(K.amberText)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .ironCard()
    }

    /// "Ändern" ist jetzt ein Vorschlag: fest wird die neue Zeit erst, wenn die Gruppe im Chat zustimmt.
    private func saveTime() async {
        guard let group = appState.activeGroup, let profile = appState.userProfile else { return }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        let hhmm = f.string(from: pickedTime)
        do {
            _ = try await APIClient.shared.chatPropose(
                groupId: group.id,
                auth: ChatAuth(userId: profile.userId, recoveryCode: profile.recoveryCode,
                               accountToken: appState.account?.accountToken),
                date: dateYMD(Date()), time: hhmm)
            await appState.refreshData()
            editing = false
            toast = K.L.de ? "Vorschlag \(hhmm) gesendet – die anderen stimmen im Chat ab." : "Proposal \(hhmm) sent – the others vote in the chat."
        } catch {
            toast = K.L.errServer
        }
    }

    private func parseTimeHHMM(_ s: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.date(from: s)
    }
}

// MARK: - Entry Row (website: .entry — initials avatar, name, date, type badge)

struct EntryRow: View {
    let entry: Entry
    var people: [Person] = []
    var adminMode = false
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var standalone: Bool = true

    private var isPendingSync: Bool { entry.id.hasPrefix("local-") }

    var body: some View {
        Group {
            if standalone {
                rowContent.glassCard()
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            if let p = people.first(where: { $0.name.lowercased() == entry.person.lowercased() }) {
                AvatarView(emoji: p.avatarEmoji, color: p.avatarColor, img: p.avatarImg, size: 40)
            } else {
                Text(initials(entry.person))
                    .font(Theme.body(13, .bold))
                    .foregroundColor(K.onAccent)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(LinearGradient(colors: Theme.accentGradient,
                                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.person)
                    .font(Theme.body(15, .semibold))
                Text(fmtFull(entry.date))
                    .font(Theme.body(12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isPendingSync {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            EntryBadge(entry: entry)

            if adminMode {
                Button { onEdit?() } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color(.secondarySystemFill)))
                }
                .buttonStyle(.plain)
                Button { onDelete?() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(K.red)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(K.red.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .opacity(isPendingSync ? 0.6 : 1)
    }
}
