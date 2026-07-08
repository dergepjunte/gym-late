import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appState: AppState

    private var weeks: [[Entry]] {
        guard let entries = appState.groupData?.entries else { return [] }
        let cal = Calendar.iso8601UTC
        let todayWeekStart = cal.startOfWeek(for: Date())

        // Group by week start (Mon), exclude current week
        var byWeek: [String: [Entry]] = [:]
        for e in entries {
            guard let d = parseDate(e.date) else { continue }
            let ws = cal.startOfWeek(for: d)
            if ws >= todayWeekStart { continue }
            let key = dateYMD(ws)
            byWeek[key, default: []].append(e)
        }
        return byWeek.keys.sorted(by: >).map { byWeek[$0]! }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if weeks.isEmpty {
                    VStack(spacing: 8) {
                        Text("📅").font(.system(size: 48))
                        Text("Noch keine abgeschlossenen Wochen")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 60)
                } else {
                    ForEach(weeks, id: \.first?.date) { weekEntries in
                        WeekHistoryCard(entries: weekEntries)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }
}

struct WeekHistoryCard: View {
    let entries: [Entry]

    private var lateEntries: [Entry] { entries.filter { $0.type == "late" } }
    private var totalMins: Int { lateEntries.reduce(0) { $0 + $1.mins } }

    private var weekLabel: String {
        guard let first = entries.first, let d = parseDate(first.date) else { return "" }
        let cal = Calendar.iso8601UTC
        let mon = cal.startOfWeek(for: d)
        let sun = cal.date(byAdding: .day, value: 6, to: mon)!
        let fmt = DateFormatter(); fmt.dateFormat = "d. MMM"; fmt.locale = Locale(identifier: "de_DE")
        return "\(fmt.string(from: mon)) – \(fmt.string(from: sun))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(weekLabel).eyebrow(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Label("\(lateEntries.count)", systemImage: "clock.fill")
                        .font(Theme.body(13, .bold)).foregroundColor(K.red)
                    Label("\(totalMins) Min", systemImage: "timer")
                        .font(Theme.body(13)).foregroundColor(.secondary)
                }
            }

            // Top late-comer
            if let king = lateEntries.max(by: { a, b in
                let aCount = lateEntries.filter { $0.person == a.person }.count
                let bCount = lateEntries.filter { $0.person == b.person }.count
                return aCount < bCount
            }) {
                let count = lateEntries.filter { $0.person == king.person }.count
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill").foregroundColor(K.gold)
                    Text(king.person).font(Theme.body(13, .bold))
                    Text("–").foregroundColor(.secondary)
                    Text("\(count)× zu spät").font(Theme.body(13)).foregroundColor(.secondary)
                }
            }

            // Mini entry list
            ForEach(lateEntries.prefix(4)) { e in
                HStack {
                    Text(e.person).font(Theme.body(13))
                    Spacer()
                    Text("\(e.mins) Min.").font(Theme.body(13, .semibold)).foregroundColor(K.red)
                }
            }
            if lateEntries.count > 4 {
                Text("+ \(lateEntries.count - 4) weitere")
                    .font(Theme.body(12)).foregroundColor(.secondary)
            }
        }
        .padding(16)
        .glassCard()
    }
}
