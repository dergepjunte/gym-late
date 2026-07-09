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

    var body: some View {
        ScrollView {
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

                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text("\(lateEntries.count)")
                            .font(Theme.display(28))
                            .foregroundColor(lateEntries.isEmpty ? .primary : K.red)
                        Text(K.L.sCountLbl)
                            .font(Theme.body(11)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Divider().frame(height: 36)
                    VStack(spacing: 2) {
                        Text("\(totalMins)")
                            .font(Theme.display(28))
                        Text(K.L.sMinLbl)
                            .font(Theme.body(11)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 12)
                .glassCard()
                .padding(.horizontal, 16)

                if !skipEntries.isEmpty {
                    Text("⊘ \(skipEntries.count) \(K.L.skipped)")
                        .font(Theme.body(12, .bold)).foregroundColor(K.gold)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(K.gold.opacity(0.14)))
                }

                // Entries
                if weekEntries.isEmpty {
                    VStack(spacing: 8) {
                        Text("🏃").font(.system(size: 48))
                        Text(K.L.emptyWeek)
                            .font(Theme.body(15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(weekEntries) { entry in
                            EntryRow(entry: entry,
                                     people: appState.groupData?.people ?? [],
                                     adminMode: appState.adminMode,
                                     onEdit: { editingEntry = entry },
                                     onDelete: { Task { await deleteEntry(entry) } })
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 20)
            }
            .padding(.top, 12)
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
    @State private var glowRadius: CGFloat = 12
    @State private var didAnimate = false

    var body: some View {
        Button { onTap() } label: {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        extendedToday
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "#fde047"), Color(hex: "#fb923c"), Color(hex: "#dc2626")],
                            startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.secondary.opacity(0.45)))
                    .shadow(color: extendedToday ? Color(hex: "#fb923c").opacity(0.55) : .clear,
                            radius: glowRadius)
                    .animation(UIAccessibility.isReduceMotionEnabled
                               ? .easeInOut(duration: 0.4) : nil, value: extendedToday)
                    .scaleEffect(scale)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(streak)")
                        .font(Theme.display(44))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundColor(extendedToday ? Color(hex: "#f97316") : .secondary)
                    Text(K.L.shDays(streak))
                        .font(Theme.body(14, .semibold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(extendedToday ? K.L.shHintDone : K.L.shHintOpen)
                    .font(Theme.body(12, .bold))
                    .foregroundColor(K.amberText)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 130, alignment: .trailing)
            }
            .padding(16)
            .glassCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(streak) \(K.L.shDays(streak))\(extendedToday ? ", \(K.L.shHintDone)" : ", \(K.L.shHintOpen)")")
        .onChange(of: extendedToday) { _, newValue in
            guard newValue, !didAnimate, !UIAccessibility.isReduceMotionEnabled else { return }
            didAnimate = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scale = 1.18
                glowRadius = 28
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    scale = 1.0
                    glowRadius = 12
                }
            }
        }
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
            Text("⏰").font(.system(size: 22))
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
                        .font(Theme.body(17, .heavy))
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
        .glassCard()
    }

    private func saveTime() async {
        guard let group = appState.activeGroup else { return }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        let hhmm = f.string(from: pickedTime)
        do {
            try await APIClient.shared.setCheckinTime(groupId: group.id,
                                                      date: dateYMD(Date()), time: hhmm)
            await appState.refreshData()
            editing = false
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

    /// Entry logged offline, still waiting to reach the server.
    private var isPendingSync: Bool { entry.id.hasPrefix("local-") }

    var body: some View {
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
        .glassCard()
    }
}
