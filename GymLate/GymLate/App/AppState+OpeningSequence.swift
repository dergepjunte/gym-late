import SwiftUI
import CoreLocation

extension AppState {
    // MARK: - Opening Sequence

    func runOpeningSequence() {
        guard let data = groupData, let group = activeGroup else { return }
        let today = dateYMD(Date())
        let cal = Calendar.iso8601UTC
        let weekStart = dateYMD(cal.startOfWeek(for: Date()))

        // 1. Wrapped (once per week, previous week has entries)
        let lastWeekMon = dateYMD(cal.date(byAdding: .weekOfYear, value: -1, to: cal.startOfWeek(for: Date()))!)
        let lastWeekSun = dateYMD(cal.date(byAdding: .day, value: 6, to: cal.date(byAdding: .weekOfYear, value: -1, to: cal.startOfWeek(for: Date()))!)!)
        let lastWeekEntries = data.entries.filter { $0.date >= lastWeekMon && $0.date <= lastWeekSun }
        let shouldShowWrapped = !store.isWrappedSeen(weekStart: weekStart) && !lastWeekEntries.isEmpty

        // 2. Daily hype: today is a scheduled gym day
        let gymDays = data.gymDays
        let dayOfWeek = cal.component(.weekday, from: Date()) // 1=Sun
        let idx = dayOfWeek == 1 ? 6 : dayOfWeek - 2         // Mon=0…Sun=6
        let todayScheduled = gymDays.count == 7 && Array(gymDays)[idx] == "1"
        let shouldShowHype = todayScheduled && !store.isDailyHypeSeen(date: today)

        // 3. Geo: enqueued after other bubbles advance
        _ = group // referenced to avoid unused warning

        // Build bubble queue (Wrapped → Hype → Geo); each appears as a pill first.
        bubbleQueue = []
        if shouldShowWrapped {
            store.markWrappedSeen(weekStart: weekStart)
            bubbleQueue.append(BubbleNotification(kind: .wrapped,
                glyph: "🎉", title: K.L.bubbleWrappedTitle, subtitle: K.L.bubbleWrappedSub))
        }
        if shouldShowHype {
            store.markDailyHypeSeen(date: today)
            bubbleQueue.append(BubbleNotification(kind: .dailyHype,
                glyph: "💪", title: K.L.bubbleHypeTitle, subtitle: K.L.bubbleHypeSub))
        }
        advanceBubbleQueue()
    }

    /// Show the next bubble in the queue, or trigger geo check when empty.
    private func advanceBubbleQueue() {
        if bubbleQueue.isEmpty {
            Task { await checkGeoPrompt() }
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
                pendingBubble = bubbleQueue.removeFirst()
            }
        }
    }

    /// Called when the user TAPS the bubble → play the full-screen animation.
    func onBubbleTapped() {
        guard let b = pendingBubble else { return }
        withAnimation(.easeOut(duration: 0.18)) { pendingBubble = nil }
        switch b.kind {
        case .wrapped:  showWrapped = true
        case .dailyHype: showDailyHype = true
        case .geo:      showGeoPrompt = true
        }
    }

    /// Called when the user DISMISSES the bubble → show replay hint and advance.
    func onBubbleDismissed() {
        guard let b = pendingBubble else { return }
        withAnimation(.easeOut(duration: 0.18)) { pendingBubble = nil }
        replayHint = (b.kind == .wrapped) ? .recap : .checkin
        // Auto-clear hint after 6 seconds
        Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            await MainActor.run { if self.replayHint != nil { self.replayHint = nil } }
        }
        advanceBubbleQueue()
    }

    func onHypeDismissed() {
        showDailyHype = false
        advanceBubbleQueue()
    }

    func onWrappedDismissed() {
        showWrapped = false
        advanceBubbleQueue()
    }

    // MARK: - Admin debug helpers (website: admin panel debug section)

    func forceDailyHype() {
        // Show as bubble first (same as production opening sequence)
        bubbleQueue = [BubbleNotification(kind: .dailyHype,
            glyph: "💪", title: K.L.bubbleHypeTitle, subtitle: K.L.bubbleHypeSub)]
        advanceBubbleQueue()
    }

    func forceGeoPrompt() {
        geoCheckinPossible = true
        bubbleQueue = [BubbleNotification(kind: .geo,
            glyph: "📍", title: K.L.bubbleGeoTitle, subtitle: K.L.bubbleGeoSub)]
        advanceBubbleQueue()
    }

    func clearTodayFlags() {
        let today = dateYMD(Date())
        store.clearDailyFlags(for: today)
    }

    func replayWrapped() {
        let weekStart = dateYMD(Calendar.iso8601UTC.startOfWeek(for: Date()))
        store.clearWrappedSeen(weekStart: weekStart)
        // Show via bubble (matches the opening sequence experience)
        bubbleQueue = [BubbleNotification(kind: .wrapped,
            glyph: "🎉", title: K.L.bubbleWrappedTitle, subtitle: K.L.bubbleWrappedSub)]
        advanceBubbleQueue()
    }

    private func checkGeoPrompt() async {
        guard store.geoEnabled else { return }
        let today = dateYMD(Date())
        guard !store.isGeoPromptSeen(date: today),
              let data = groupData,
              let gymLat = data.gymLat, let gymLng = data.gymLng else { return }

        // Mirror web's checkGeoAndPrompt: skip if the user already has an
        // attend/late entry for today (opening.js:66-73) — otherwise a
        // check-in logged another way still triggers the geo prompt.
        let me = userProfile?.name
        let alreadyIn = data.entries.contains { e in
            me != nil && e.person == me && e.date == today && (e.type == "attend" || e.type == "late")
        }
        guard !alreadyIn else { return }

        let radius = Double(data.gymRadius ?? 150)

        do {
            let loc = try await LocationManager.shared.fetchCurrentLocation()
            let gymCoord = CLLocationCoordinate2D(latitude: gymLat, longitude: gymLng)
            let dist = LocationManager.distance(from: loc.coordinate, to: gymCoord)
            if dist <= radius {
                // Only mark "seen" once the prompt is actually about to show —
                // matches web's showGeoPrompt(), which sets the flag itself
                // rather than the caller pre-marking it. Keeps retrying (e.g.
                // next poll) if the user is still out of range today.
                store.markGeoPromptSeen(date: today)
                geoCheckinPossible = true
                showGeoPrompt = true
            }
        } catch {}
    }
}
