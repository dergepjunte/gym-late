import SwiftUI
import Charts

/// Rückblick tab — week blocks with a ranking list, mirrors the website's
/// #pane-recap (renderHistory): one full-height block per completed week,
/// hero with the most-often-late member, rows ranked by minutes.
struct RecapView: View {
    @EnvironmentObject var appState: AppState
    @State private var toast: String?

    private struct PersonStat {
        var count = 0, mins = 0, skips = 0, attends = 0
    }

    private struct WeekBlock: Identifiable {
        let id: String            // week start (Monday, yyyy-MM-dd)
        let end: String           // Sunday
        let byMins: [(name: String, stat: PersonStat)]
        let skipOnly: [(name: String, stat: PersonStat)]
        let totalLateMins: Int
        let lateMinsPerDay: [(label: String, mins: Int)]   // 7 entries Mon–Sun
        let mostPunctual: (name: String, count: Int)?
    }

    private var blocks: [WeekBlock] {
        guard let entries = appState.groupData?.entries else { return [] }
        let currentMon = dateYMD(Calendar.iso8601UTC.startOfWeek(for: Date()))

        var weeks: [String: [Entry]] = [:]
        for e in entries {
            guard let d = parseDate(e.date) else { continue }
            let mon = dateYMD(Calendar.iso8601UTC.startOfWeek(for: d))
            if mon == currentMon && !appState.adminShowCurrentWeek { continue }
            weeks[mon, default: []].append(e)
        }

        return weeks.keys.sorted(by: >).map { mon in
            let sun = dateYMD(Calendar.iso8601UTC.date(byAdding: .day, value: 6, to: parseDate(mon)!)!)
            var ps: [String: PersonStat] = [:]
            for e in weeks[mon]! where e.type == "late" || e.type.isEmpty {
                ps[e.person, default: PersonStat()].count += 1
                ps[e.person, default: PersonStat()].mins += e.mins
            }
            for e in weeks[mon]! where e.type == "skip" {
                ps[e.person, default: PersonStat()].skips += 1
            }
            for e in weeks[mon]! where e.type == "attend" {
                ps[e.person, default: PersonStat()].attends += 1
            }

            var minsPerDay = Array(repeating: 0, count: 7)
            for e in weeks[mon]! where (e.type == "late" || e.type.isEmpty) {
                minsPerDay[isoWeekdayIndex(e.date)] += e.mins
            }
            let lateMinsPerDay = K.L.dayNames.enumerated().map { (i, label) in
                (label: label, mins: minsPerDay[i])
            }

            let totalLateMins = ps.values.reduce(0) { $0 + $1.mins }
            let mostPunctual: (name: String, count: Int)? = ps
                .filter { $0.value.attends > 0 }
                .max { $0.value.attends < $1.value.attends }
                .map { (name: $0.key, count: $0.value.attends) }

            let byMins = ps.filter { $0.value.count > 0 }
                .sorted { ($0.value.mins, $0.value.count) > ($1.value.mins, $1.value.count) }
                .map { (name: $0.key, stat: $0.value) }
            let skipOnly = ps.filter { $0.value.count == 0 && $0.value.skips > 0 }
                .sorted { $0.value.skips > $1.value.skips }
                .map { (name: $0.key, stat: $0.value) }
            return WeekBlock(id: mon, end: sun, byMins: byMins, skipOnly: skipOnly,
                             totalLateMins: totalLateMins, lateMinsPerDay: lateMinsPerDay,
                             mostPunctual: mostPunctual)
        }
    }

    var body: some View {
        let blocks = self.blocks
        Group {
            if blocks.isEmpty {
                VStack(spacing: 0) {
                    AppHeader(toast: $toast)
                    VStack(spacing: 8) {
                        Text("📅").font(.system(size: 48))
                        Text(K.L.emptyHistory)
                            .font(Theme.body(15)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        AppHeader(toast: $toast)
                        LazyVStack(spacing: 24) {
                            // Replay Wrapped button — always visible, matches bubble dismiss hint
                            Button {
                                appState.replayWrapped()
                            } label: {
                                Label(K.L.recapReplayBtn, systemImage: "play.fill")
                                    .font(Theme.body(13, .semibold))
                                    .foregroundColor(K.accentDark)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 9)
                                    .frame(maxWidth: .infinity)
                                    .glassButton()
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                            ForEach(Array(blocks.enumerated()), id: \.element.id) { i, block in
                                weekBlockView(block, previousBlock: i + 1 < blocks.count ? blocks[i + 1] : nil)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .toast($toast)
    }

    @ViewBuilder
    private func weekBlockView(_ block: WeekBlock, previousBlock: WeekBlock?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(K.L.weekRange(block.id, block.end)).eyebrow()
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // Hero: most-often-late or "all skipped"
                if let top = block.byMins.first {
                    VStack(spacing: 6) {
                        Text("★")
                            .font(.system(size: 44))
                            .foregroundStyle(LinearGradient(colors: Theme.accentGradient,
                                                            startPoint: .top, endPoint: .bottom))
                        Text(top.name).font(Theme.heading(22))
                        Text(K.L.lateKing).font(Theme.body(13)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 6) {
                        Text("⊘").font(.system(size: 36))
                        Text(K.L.allSkippedTitle).font(Theme.heading(18))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }

                // Ranked rows (by minutes, like the website)
                ForEach(Array(block.byMins.enumerated()), id: \.element.name) { i, row in
                    rankRow(rank: "\(i + 1).", gold: i == 0,
                            name: row.name,
                            skipTag: row.stat.skips,
                            meta: K.L.timesLate(row.stat.count),
                            badge: .late(row.stat.mins))
                }
                ForEach(block.skipOnly, id: \.name) { row in
                    rankRow(rank: "⊘", gold: false,
                            name: row.name,
                            skipTag: 0,
                            meta: "\(row.stat.skips)× \(K.L.skipped)",
                            badge: .skip(row.stat.skips))
                }

                // Card A — trend chart
                Divider().padding(.vertical, 4)
                trendChart(block)

                // Card B — week comparison
                Divider().padding(.vertical, 4)
                comparisonCard(block, previousBlock: previousBlock)

                // Card C — positive cards (only when there's something to show)
                positiveCards(block, previousBlock: previousBlock)
            }
            .glassCard()
        }
    }

    // MARK: - Card A: Trend chart

    @ViewBuilder
    private func trendChart(_ block: WeekBlock) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(K.L.recapTrendTitle)
                .font(Theme.body(12)).foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 10)

            Chart(block.lateMinsPerDay, id: \.label) { item in
                BarMark(
                    x: .value("Day", item.label),
                    y: .value("Min", item.mins == 0 ? 2 : item.mins)
                )
                .foregroundStyle(item.mins == 0 ? Color.secondary.opacity(0.15) : K.red.opacity(0.7))
                .accessibilityLabel("\(item.label), \(item.mins) \(K.L.minsShort)")
            }
            .chartXScale(domain: K.L.dayNames)
            .chartYAxis(.hidden)
            .frame(height: 100)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Card B: Week comparison

    @ViewBuilder
    private func comparisonCard(_ block: WeekBlock, previousBlock: WeekBlock?) -> some View {
        HStack(spacing: 10) {
            if let prev = previousBlock {
                let delta = block.totalLateMins - prev.totalLateMins
                let symbol = delta < 0 ? "arrow.down" : delta == 0 ? "arrow.right" : "arrow.up"
                let color: Color = delta < 0 ? K.green : delta == 0 ? K.gold : K.red
                Image(systemName: symbol).foregroundColor(color).font(.system(size: 14, weight: .bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(delta < 0 ? "−\(abs(delta)) \(K.L.minsShort)" : delta == 0 ? "±0 \(K.L.minsShort)" : "+\(delta) \(K.L.minsShort)")
                        .font(Theme.body(13, .bold)).foregroundColor(color)
                    Text(delta < 0 ? K.L.recapBetterWeek : delta == 0 ? K.L.recapSameWeek : K.L.recapWorseWeek)
                        .font(Theme.body(12)).foregroundColor(.secondary)
                }
            } else {
                Image(systemName: "minus").foregroundColor(.secondary).font(.system(size: 14))
                Text(K.L.recapFirstWeek)
                    .font(Theme.body(12)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Card C: Positive cards

    @ViewBuilder
    private func positiveCards(_ block: WeekBlock, previousBlock: WeekBlock?) -> some View {
        let improved: (name: String, delta: Int)? = {
            guard let prev = previousBlock else { return nil }
            return block.byMins.compactMap { row -> (name: String, delta: Int)? in
                let prevMins = prev.byMins.first { $0.name == row.name }?.stat.mins ?? 0
                let delta = prevMins - row.stat.mins
                return delta > 0 ? (name: row.name, delta: delta) : nil
            }.max { $0.delta < $1.delta }
        }()

        if block.mostPunctual != nil || improved != nil {
            Divider().padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 8) {
                if let p = block.mostPunctual {
                    positiveRow(icon: "🏅", label: K.L.recapMostPunctual,
                                name: p.name, meta: K.L.recapOnTime(p.count))
                }
                if let imp = improved {
                    positiveRow(icon: "📈", label: K.L.recapMostImproved,
                                name: imp.name, meta: K.L.recapImprovedBy(imp.delta))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func positiveRow(icon: String, label: String, name: String, meta: String) -> some View {
        HStack(spacing: 10) {
            Text(icon).font(.system(size: 18))
            if let p = appState.groupData?.person(named: name) {
                AvatarView(emoji: p.avatarEmoji, color: p.avatarColor, img: p.avatarImg, size: 32)
            } else {
                Text(initials(name))
                    .font(Theme.body(11, .bold)).foregroundColor(K.onAccent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(LinearGradient(colors: Theme.accentGradient,
                                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(Theme.body(11)).foregroundColor(.secondary)
                Text(name).font(Theme.body(13, .bold))
            }
            Spacer()
            Text(meta).font(Theme.body(12)).foregroundColor(.secondary)
        }
    }

    // MARK: - Rank row

    private enum RankBadge {
        case late(Int), skip(Int)
    }

    @ViewBuilder
    private func rankRow(rank: String, gold: Bool, name: String, skipTag: Int,
                         meta: String, badge: RankBadge) -> some View {
        HStack(spacing: 12) {
            Text(rank)
                .font(Theme.body(14, .bold))
                .foregroundColor(gold ? K.gold : .secondary)
                .frame(width: 26)
            if let p = appState.groupData?.person(named: name) {
                AvatarView(emoji: p.avatarEmoji, color: p.avatarColor, img: p.avatarImg, size: 38)
            } else {
                Text(initials(name))
                    .font(Theme.body(13, .bold))
                    .foregroundColor(K.onAccent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(LinearGradient(colors: Theme.accentGradient,
                                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name).font(Theme.body(14, .semibold))
                    if skipTag > 0 {
                        Text("⊘\(skipTag)")
                            .font(Theme.body(10, .bold)).foregroundColor(K.gold)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(K.gold.opacity(0.14)))
                    }
                }
                Text(meta).font(Theme.body(12)).foregroundColor(.secondary)
            }
            Spacer()
            switch badge {
            case .late(let mins):
                Text("\(mins) \(K.L.minsShort)")
                    .font(Theme.body(13, .bold)).foregroundColor(K.red)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(K.red.opacity(0.14)))
            case .skip(let n):
                Text("⊘ \(n)")
                    .font(Theme.body(13, .bold)).foregroundColor(K.gold)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(K.gold.opacity(0.14)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(gold ? K.gold.opacity(0.06) : .clear)
    }
}
