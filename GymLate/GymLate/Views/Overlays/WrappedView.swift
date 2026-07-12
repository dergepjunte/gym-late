import SwiftUI

// MARK: - WrappedView (web-parity: w-in/out, progress bar, count-up, tap zones)

struct WrappedView: View {
    let onDismiss: () -> Void
    @EnvironmentObject var appState: AppState

    @State private var idx = 0
    @State private var progress: CGFloat = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var exitScale: CGFloat = 1
    @State private var exitOpacity: CGFloat = 0   // starts 0; enter sets to 1
    @State private var shakeX: CGFloat = 0

    // MARK: - Slide data

    private struct Slide {
        let gradient: [Color]
        let kind: Kind
        let duration: Double
        var isLast = false

        enum Kind {
            case intro(groupName: String, weekRange: String)
            case lateCount(Int)
            case minutes(total: Int)
            case king(name: String, count: Int, mins: Int)
            case ranking([(name: String, count: Int, mins: Int)])
            case cta
        }
    }

    private var slides: [Slide] {
        guard let entries = appState.groupData?.entries,
              let groupName = appState.groupData?.name else { return [] }
        let cal = Calendar.iso8601UTC
        let lastMon = cal.date(byAdding: .weekOfYear, value: -1,
                               to: cal.startOfWeek(for: Date()))!
        let lastSun = cal.date(byAdding: .day, value: 6, to: lastMon)!
        let monStr = dateYMD(lastMon), sunStr = dateYMD(lastSun)
        let lateEntries = entries.filter {
            $0.date >= monStr && $0.date <= sunStr && ($0.type == "late" || $0.type.isEmpty)
        }
        guard !lateEntries.isEmpty else { return [] }

        let totalMins = lateEntries.reduce(0) { $0 + $1.mins }
        var ps: [String: (count: Int, mins: Int)] = [:]
        for e in lateEntries {
            let old = ps[e.person] ?? (0, 0)
            ps[e.person] = (old.count + 1, old.mins + e.mins)
        }
        let ranking = ps.sorted { $0.value.mins > $1.value.mins }
            .map { (name: $0.key, count: $0.value.count, mins: $0.value.mins) }
        let top = ranking[0]

        var out: [Slide] = [
            Slide(gradient: Theme.slideTitle,
                  kind: .intro(groupName: groupName,
                               weekRange: K.L.weekRange(monStr, sunStr)), duration: 3),
            Slide(gradient: Theme.slideLate,
                  kind: .lateCount(lateEntries.count), duration: 4),
            Slide(gradient: Theme.slideMinutes,
                  kind: .minutes(total: totalMins), duration: 4),
            Slide(gradient: Theme.slideKing,
                  kind: .king(name: top.name, count: top.count, mins: top.mins), duration: 4.5),
        ]
        if ranking.count > 1 {
            out.append(Slide(gradient: Theme.slideRanking,
                             kind: .ranking(ranking), duration: 5))
        }
        out.append(Slide(gradient: Theme.slideCTA, kind: .cta, duration: 99, isLast: true))
        return out
    }

    // MARK: - Body

    var body: some View {
        let slides = self.slides
        GeometryReader { geo in
            ZStack {
                // Gradient background (animates on slide change)
                let grad = slideIndex < slides.count ? slides[slideIndex].gradient : Theme.slideCTA
                LinearGradient(colors: grad, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.35), value: idx)

                // Specular highlight overlay (web: .w-slide::before)
                LinearGradient(stops: [
                    .init(color: .white.opacity(0.12), location: 0),
                    .init(color: .clear, location: 0.55)
                ], startPoint: UnitPoint(x: 0.25, y: 0.15), endPoint: .center)
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // Slide content — keyed by idx so SwiftUI treats each as fresh
                if slideIndex < slides.count {
                    slideContent(slides[slideIndex])
                        .id(idx)
                        .scaleEffect(exitScale)
                        .opacity(exitOpacity)
                        .ignoresSafeArea()
                }

                // Progress bar
                VStack {
                    progressBar(count: slides.count)
                        .padding(.horizontal, 12)
                        .padding(.top, geo.safeAreaInsets.top + 10)
                    Spacer()
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // Skip / close button (top right, like web .w-skip)
                VStack {
                    HStack {
                        Spacer()
                        Button { onDismiss() } label: {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 36, height: 36)
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                        .padding(.top, geo.safeAreaInsets.top + 12)
                    }
                    Spacer()
                }
                .ignoresSafeArea()

                // Tap zones: left 33% → back, right 67% → forward
                HStack(spacing: 0) {
                    Color.clear.contentShape(Rectangle())
                        .frame(width: geo.size.width * 0.33)
                        .onTapGesture { advance(-1, in: slides) }
                    Color.clear.contentShape(Rectangle())
                        .frame(maxWidth: .infinity)
                        .onTapGesture { advance(1, in: slides) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }
        }
        .offset(x: shakeX)
        .ignoresSafeArea()
        .onAppear {
            // Enter first slide
            withAnimation(.easeOut(duration: 0.3)) {
                exitScale = 1; exitOpacity = 1
            }
            if !slides.isEmpty { startTimer(duration: slides[0].duration, in: slides) }
        }
        .onDisappear { timerTask?.cancel() }
    }

    private var slideIndex: Int { min(idx, max(0, slides.count - 1)) }

    // MARK: - Progress bar

    @ViewBuilder
    private func progressBar(count: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.28))
                        if i < idx {
                            Capsule().fill(Color.white.opacity(0.9))
                        } else if i == idx {
                            Capsule()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: g.size.width * progress)
                                .animation(.linear(duration: 0.016), value: progress)
                        }
                    }
                }
                .frame(height: 3)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Timer

    private func startTimer(duration: Double, in slides: [Slide]) {
        timerTask?.cancel()
        progress = 0
        let start = Date.now
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000)
                let p = CGFloat(min(Date.now.timeIntervalSince(start) / duration, 1.0))
                await MainActor.run { progress = p }
                if p >= 1 {
                    await MainActor.run { advance(1, in: slides) }
                    return
                }
            }
        }
    }

    // MARK: - Navigation

    private func advance(_ dir: Int, in slides: [Slide]) {
        timerTask?.cancel()
        let next = idx + dir
        guard next >= 0 else {
            // Shake — web: wAdvance(-1) shakes the slide
            withAnimation(.interpolatingSpring(stiffness: 500, damping: 12)) { shakeX = -14 }
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { shakeX = 0 }
                }
            }
            startTimer(duration: slides[idx].duration, in: slides)
            return
        }
        guard next < slides.count else { onDismiss(); return }

        // Exit: scale down + fade (web: w-out .22s ease-in)
        withAnimation(.easeIn(duration: 0.22)) {
            exitScale = 0.94
            exitOpacity = 0
        }
        Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            await MainActor.run {
                idx = next
                exitScale = 1.06      // enter starts slightly bigger
                exitOpacity = 0
            }
            try? await Task.sleep(nanoseconds: 16_000_000)
            // Enter: scale 1.06→1 + fade in (web: w-in .3s ease-out)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    exitScale = 1.0
                    exitOpacity = 1.0
                }
                startTimer(duration: slides[next].duration, in: slides)
            }
        }
    }

    // MARK: - Slide content dispatch

    @ViewBuilder
    private func slideContent(_ slide: Slide) -> some View {
        ZStack {
            switch slide.kind {
            case .intro(let groupName, let weekRange):
                introSlide(groupName: groupName, weekRange: weekRange)
            case .lateCount(let count):
                lateCountSlide(count: count)
            case .minutes(let total):
                minutesSlide(total: total)
            case .king(let name, let count, let mins):
                kingSlide(name: name, count: count, mins: mins)
            case .ranking(let rows):
                rankingSlide(rows: rows)
            case .cta:
                ctaSlide()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}
