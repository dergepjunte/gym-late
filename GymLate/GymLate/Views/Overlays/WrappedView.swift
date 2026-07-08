import SwiftUI

/// Full-screen Spotify Wrapped–style overlay triggered once per week.
struct WrappedView: View {
    let onDismiss: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var slideIndex = 0

    private var lastWeekEntries: [Entry] {
        guard let entries = appState.groupData?.entries else { return [] }
        let cal = Calendar.iso8601UTC
        let lastMon = cal.date(byAdding: .weekOfYear, value: -1, to: cal.startOfWeek(for: Date()))!
        let lastSun = cal.date(byAdding: .day, value: 6, to: lastMon)!
        return entries.filter { $0.date >= dateYMD(lastMon) && $0.date <= dateYMD(lastSun) }
    }

    private var lateEntries: [Entry] { lastWeekEntries.filter { $0.type == "late" } }
    private var totalMins: Int { lateEntries.reduce(0) { $0 + $1.mins } }
    private var lateKing: String? {
        Dictionary(grouping: lateEntries, by: \.person)
            .max(by: { $0.value.count < $1.value.count })?.key
    }

    private var slideCount: Int { lateKing != nil ? 5 : 4 }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $slideIndex) {
                // Slide 0: Title
                WrappedSlide(gradient: Theme.slideTitle) {
                    VStack(spacing: 8) {
                        Text("DIESE").font(.system(size: 44, weight: .black)).foregroundColor(.white.opacity(0.6))
                        Text("WOCHE").font(.system(size: 64, weight: .black)).foregroundColor(.white)
                    }
                }.tag(0)

                // Slide 1: Late count
                WrappedSlide(gradient: Theme.slideLate) {
                    VStack(spacing: 8) {
                        Text("ihr wart").font(.system(size: 20)).foregroundColor(.white.opacity(0.7))
                        Text("\(lateEntries.count)×").font(.system(size: 88, weight: .black)).foregroundColor(.white)
                        Text("zu spät").font(.system(size: 20)).foregroundColor(.white.opacity(0.7))
                    }
                }.tag(1)

                // Slide 2: Total minutes
                WrappedSlide(gradient: Theme.slideMinutes) {
                    VStack(spacing: 8) {
                        Text("ihr habt verbraten").font(.system(size: 18)).foregroundColor(.white.opacity(0.7))
                        Text("\(totalMins)").font(.system(size: 88, weight: .black)).foregroundColor(.white)
                        Text("Minuten").font(.system(size: 20)).foregroundColor(.white.opacity(0.7))
                        if totalMins >= 60 {
                            Text("das sind \(totalMins/60)h \(totalMins%60)min")
                                .font(.system(size: 15)).foregroundColor(.white.opacity(0.5))
                        }
                    }
                }.tag(2)

                // Slide 3: King (optional)
                if let king = lateKing {
                    WrappedSlide(gradient: Theme.slideKing) {
                        VStack(spacing: 16) {
                            Text("👑").font(.system(size: 88))
                            Text(king).font(.system(size: 44, weight: .black)).foregroundColor(.white)
                            Text("Zuspätkommer\nder Woche")
                                .font(.system(size: 18)).foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }.tag(3)
                }

                // Last slide: CTA
                WrappedSlide(gradient: Theme.slideCTA) {
                    VStack(spacing: 16) {
                        Text("NÄCHSTE").font(.system(size: 38, weight: .black)).foregroundColor(.white.opacity(0.6))
                        Text("WOCHE\nBESSER.").font(.system(size: 52, weight: .black)).foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Button {
                            hapticSuccess()
                            onDismiss()
                        } label: {
                            Text("Los geht's")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(K.accentDark)
                                .padding(.horizontal, 40).padding(.vertical, 16)
                                .background(Color.white.cornerRadius(20))
                        }
                    }
                }.tag(slideCount - 1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .ignoresSafeArea()

            // Skip button
            Button {
                haptic(.light)
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(20)
            .padding(.top, 44)
        }
    }
}

struct WrappedSlide<Content: View>: View {
    let gradient: [Color]
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            content()
        }
    }
}
