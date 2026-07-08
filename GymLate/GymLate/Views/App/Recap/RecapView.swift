import SwiftUI

/// Wrapped-style weekly recap — shows last week's summary as story slides.
struct RecapView: View {
    @EnvironmentObject var appState: AppState
    @State private var slideIndex = 0

    private var lastWeekEntries: [Entry] {
        guard let entries = appState.groupData?.entries else { return [] }
        let cal = Calendar.iso8601UTC
        let lastMon = cal.date(byAdding: .weekOfYear, value: -1, to: cal.startOfWeek(for: Date()))!
        let lastSun = cal.date(byAdding: .day, value: 6, to: lastMon)!
        let monStr = dateYMD(lastMon); let sunStr = dateYMD(lastSun)
        return entries.filter { $0.date >= monStr && $0.date <= sunStr }
    }

    private var lateEntries: [Entry] { lastWeekEntries.filter { $0.type == "late" } }
    private var totalMins: Int { lateEntries.reduce(0) { $0 + $1.mins } }
    private var lateKing: String? {
        let counts = Dictionary(grouping: lateEntries, by: \.person).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key
    }

    var body: some View {
        if lastWeekEntries.isEmpty {
            VStack(spacing: 16) {
                Text("📊").font(.system(size: 60))
                Text("Noch kein Rückblick")
                    .font(.title3.bold())
                Text("Komm nächste Woche wieder!")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            TabView(selection: $slideIndex) {
                SlideView(index: 0, content: {
                    VStack(spacing: 12) {
                        Text("LETZTE").font(.system(size: 40, weight: .black)).foregroundColor(.white.opacity(0.7))
                        Text("WOCHE").font(.system(size: 60, weight: .black)).foregroundColor(.white)
                    }
                })
                .tag(0)

                SlideView(index: 1, content: {
                    VStack(spacing: 8) {
                        Text("ihr wart").font(.system(size: 22)).foregroundColor(.white.opacity(0.7))
                        Text("\(lateEntries.count)×").font(.system(size: 80, weight: .black)).foregroundColor(.white)
                        Text("zu spät").font(.system(size: 22)).foregroundColor(.white.opacity(0.7))
                    }
                })
                .tag(1)

                SlideView(index: 2, content: {
                    VStack(spacing: 8) {
                        Text("ihr habt verbraten").font(.system(size: 18)).foregroundColor(.white.opacity(0.7))
                        Text("\(totalMins)").font(.system(size: 80, weight: .black)).foregroundColor(.white)
                        Text("Minuten").font(.system(size: 22)).foregroundColor(.white.opacity(0.7))
                        if totalMins >= 60 {
                            Text("das sind \(totalMins / 60)h \(totalMins % 60)min")
                                .font(.system(size: 15)).foregroundColor(.white.opacity(0.5))
                        }
                    }
                })
                .tag(2)

                if let king = lateKing {
                    SlideView(index: 3, content: {
                        VStack(spacing: 12) {
                            Text("👑").font(.system(size: 80))
                            Text(king).font(.system(size: 40, weight: .black)).foregroundColor(.white)
                            Text("Zuspätkommer der Woche").font(.system(size: 16)).foregroundColor(.white.opacity(0.7))
                        }
                    })
                    .tag(3)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }
}

struct SlideView<Content: View>: View {
    let index: Int
    @ViewBuilder let content: () -> Content

    private var bgColors: [[Color]] { Theme.slides }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: bgColors[index % bgColors.count],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            content()
        }
    }
}
