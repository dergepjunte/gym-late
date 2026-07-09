import SwiftUI

/// Rückblick tab — week blocks with a ranking list, mirrors the website's
/// #pane-recap (renderHistory): one full-height block per completed week,
/// hero with the most-often-late member, rows ranked by minutes.
struct RecapView: View {
    @EnvironmentObject var appState: AppState

    private struct PersonStat {
        var count = 0, mins = 0, skips = 0
    }

    private struct WeekBlock: Identifiable {
        let id: String            // week start (Monday, yyyy-MM-dd)
        let end: String           // Sunday
        let byMins: [(name: String, stat: PersonStat)]
        let skipOnly: [(name: String, stat: PersonStat)]
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
            let byMins = ps.filter { $0.value.count > 0 }
                .sorted { ($0.value.mins, $0.value.count) > ($1.value.mins, $1.value.count) }
                .map { (name: $0.key, stat: $0.value) }
            let skipOnly = ps.filter { $0.value.count == 0 && $0.value.skips > 0 }
                .sorted { $0.value.skips > $1.value.skips }
                .map { (name: $0.key, stat: $0.value) }
            return WeekBlock(id: mon, end: sun, byMins: byMins, skipOnly: skipOnly)
        }
    }

    var body: some View {
        let blocks = self.blocks
        if blocks.isEmpty {
            VStack(spacing: 8) {
                Text("📅").font(.system(size: 48))
                Text(K.L.emptyHistory)
                    .font(Theme.body(15)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(blocks) { block in
                        weekBlockView(block)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func weekBlockView(_ block: WeekBlock) -> some View {
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
            }
            .glassCard()
        }
    }

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
            Text(initials(name))
                .font(Theme.body(13, .bold))
                .foregroundColor(K.onAccent)
                .frame(width: 38, height: 38)
                .background(Circle().fill(LinearGradient(colors: Theme.accentGradient,
                                                         startPoint: .topLeading, endPoint: .bottomTrailing)))
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
