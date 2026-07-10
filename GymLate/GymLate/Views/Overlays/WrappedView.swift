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

    // MARK: - Individual slides

    @ViewBuilder
    private func introSlide(groupName: String, weekRange: String) -> some View {
        VStack(spacing: 0) {
            WFade(delay: 0) {
                Text(groupName.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.5)
                    .multilineTextAlignment(.center)
            }
            Spacer().frame(height: 14)
            WPop(delay: 0) {
                Text("🏋️").font(.system(size: 64))
            }
            Spacer().frame(height: 14)
            WRise(delay: 0.25) {
                Text(K.L.de ? "DIESE" : "THIS")
                    .font(.system(size: 72, weight: .black).italic())
                    .foregroundColor(.white)
                    .tracking(-3)
            }
            WRise(delay: 0.4) {
                Text(K.L.de ? "WOCHE" : "WEEK")
                    .font(.system(size: 72, weight: .black).italic())
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(-3)
            }
            Spacer().frame(height: 24)
            WFade(delay: 0.65) {
                Text(weekRange)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private func lateCountSlide(count: Int) -> some View {
        VStack(spacing: 0) {
            WFade(delay: 0) {
                Text((K.L.de ? "ihr wart" : "you were late").uppercased())
                    .wLabel()
            }
            Spacer().frame(height: 8)
            WPop(delay: 0.1) {
                WCountUp(target: count, delay: 0.28)
                    .wNumber()
            }
            Spacer().frame(height: 8)
            WRise(delay: 0.3) {
                Text(K.L.de ? "zu spät" : "times")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
                    .tracking(-0.5)
            }
            Spacer().frame(height: 24)
            WPop(delay: 0.5) {
                Text("🚨").font(.system(size: 58))
            }
        }
    }

    @ViewBuilder
    private func minutesSlide(total: Int) -> some View {
        let hours = total / 60, remMins = total % 60
        VStack(spacing: 0) {
            WFade(delay: 0) {
                Text((K.L.de ? "ihr habt verbraten" : "you wasted").uppercased())
                    .wLabel()
            }
            Spacer().frame(height: 8)
            WPop(delay: 0.1) {
                WCountUp(target: total, delay: 0.28)
                    .wNumber()
            }
            WRise(delay: 0.3) {
                Text(K.L.de ? "Minuten" : "minutes")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
                    .tracking(-0.5)
            }
            if hours > 0 {
                Spacer().frame(height: 14)
                WFade(delay: 0.55) {
                    Text(K.L.de
                         ? "das sind \(hours)h \(remMins)min"
                         : "that's \(hours)h \(remMins)min")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }

    @ViewBuilder
    private func kingSlide(name: String, count: Int, mins: Int) -> some View {
        VStack(spacing: 0) {
            WPop(delay: 0) {
                Text("👑").font(.system(size: 64))
            }
            Spacer().frame(height: 14)
            WRise(delay: 0.2) {
                Text((K.L.de ? "Zuspätkommer der Woche" : "Latecomer of the Week").uppercased())
                    .wLabel()
                    .multilineTextAlignment(.center)
            }
            Spacer().frame(height: 14)
            WPop(delay: 0.38) {
                Text(name)
                    .font(.system(size: 52, weight: .black).italic())
                    .foregroundColor(.white)
                    .tracking(-2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)
            }
            Spacer().frame(height: 24)
            WFade(delay: 0.6) {
                Text("\(count)× · \(mins) \(K.L.minsShort)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    @ViewBuilder
    private func rankingSlide(rows: [(name: String, count: Int, mins: Int)]) -> some View {
        VStack(spacing: 0) {
            WRise(delay: 0) {
                Text((K.L.de ? "Die Rangliste" : "The Ranking").uppercased())
                    .font(.system(size: 48, weight: .black).italic())
                    .foregroundColor(.white)
                    .tracking(-2)
                    .multilineTextAlignment(.center)
            }
            Spacer().frame(height: 14)
            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 44, height: 3)
                .clipShape(Capsule())
            Spacer().frame(height: 14)
            ForEach(Array(rows.prefix(5).enumerated()), id: \.offset) { i, row in
                WRise(delay: 0.2 + Double(i) * 0.13) {
                    HStack(spacing: 14) {
                        Text(["🥇","🥈","🥉"][safe: i] ?? "\(i+1).")
                            .font(.system(size: 22))
                            .frame(width: 28)
                        Text(row.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                        Text("\(row.mins) \(K.L.minsShort)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 11)
                    .overlay(alignment: .bottom) {
                        if i < min(rows.count, 5) - 1 {
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 360)
    }

    @ViewBuilder
    private func ctaSlide() -> some View {
        VStack(spacing: 0) {
            WPop(delay: 0) {
                Text("💪").font(.system(size: 64))
            }
            Spacer().frame(height: 14)
            WRise(delay: 0.2) {
                Text(K.L.de ? "NÄCHSTE" : "DO BETTER")
                    .font(.system(size: 68, weight: .black).italic())
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(-3)
                    .multilineTextAlignment(.center)
            }
            WRise(delay: 0.36) {
                Text(K.L.de ? "WOCHE\nBESSER." : "NEXT WEEK.")
                    .font(.system(size: 68, weight: .black).italic())
                    .foregroundColor(.white)
                    .tracking(-3)
                    .multilineTextAlignment(.center)
            }
            Spacer().frame(height: 40)
            WPop(delay: 0.6) {
                Button {
                    hapticSuccess()
                    onDismiss()
                } label: {
                    Text(K.L.de ? "Los geht's" : "Let's go")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(Color(hex: "#1a0030"))
                        .padding(.horizontal, 52)
                        .padding(.vertical, 18)
                        .background(Color.white.cornerRadius(40))
                        .shadow(color: .black.opacity(0.4), radius: 28, y: 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Animation helpers (web: w-pop, w-rise, w-fade)

private struct WPop<Content: View>: View {
    let delay: Double
    @ViewBuilder let content: () -> Content
    @State private var appeared = false

    var body: some View {
        content()
            .scaleEffect(appeared ? 1 : 0.3)
            .rotationEffect(.degrees(appeared ? 0 : -6))
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(delay)) {
                    appeared = true
                }
            }
    }
}

private struct WRise<Content: View>: View {
    let delay: Double
    @ViewBuilder let content: () -> Content
    @State private var appeared = false

    var body: some View {
        content()
            .offset(y: appeared ? 0 : 36)
            .blur(radius: appeared ? 0 : 6)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.interpolatingSpring(stiffness: 120, damping: 18).delay(delay)) {
                    appeared = true
                }
            }
    }
}

private struct WFade<Content: View>: View {
    let delay: Double
    @ViewBuilder let content: () -> Content
    @State private var appeared = false

    var body: some View {
        content()
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                    appeared = true
                }
            }
    }
}

// Count-up number (web: wCount with ease-out cubic)
private struct WCountUp: View {
    let target: Int
    let delay: Double
    @State private var value = 0

    var body: some View {
        Text("\(value)")
            .onAppear {
                Task {
                    if delay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                    let dur = min(1.4, 0.5 + Double(target) * 0.025)
                    let start = Date.now
                    while true {
                        let elapsed = max(0, Date.now.timeIntervalSince(start))
                        let p = min(elapsed / dur, 1.0)
                        let e = 1 - pow(1 - p, 3)          // ease-out cubic
                        await MainActor.run { value = Int(Double(target) * e) }
                        if p >= 1 { await MainActor.run { value = target }; break }
                        try? await Task.sleep(nanoseconds: 16_000_000)
                    }
                }
            }
    }
}

// MARK: - Text style helpers

private extension Text {
    func wLabel() -> some View {
        self
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white.opacity(0.6))
            .tracking(1)
            .textCase(.uppercase)
    }

    func wNumber() -> some View {
        self
            .font(.system(size: 110, weight: .black).italic()
                .monospacedDigit())
            .foregroundColor(.white)
            .tracking(-5)
    }
}

private extension View {
    func wNumber() -> some View {
        self
            .font(.system(size: 110, weight: .black).italic()
                .monospacedDigit())
            .foregroundColor(.white)
    }
}

// Safe array subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
