import Foundation
import Combine
import CoreLocation
import SwiftUI

/// A passive opening-sequence prompt shown as a glass pill above the nav bar.
/// Tapping plays the full-screen animation; dismissing shows a replay hint.
struct BubbleNotification: Equatable, Identifiable {
    enum Kind { case wrapped, dailyHype, geo }
    let id = UUID()
    let kind: Kind
    let glyph: String
    let title: String
    let subtitle: String
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var activeGroup: GroupInfo?
    @Published var groupData: GroupData?
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Offline / sync state
    @Published var isOffline = false
    @Published var pendingSyncCount = 0

    // Notification priming overlay (one-time, shown on first group entry)
    @Published var showNotifPrimer = false

    // Opening sequence overlays (set when a bubble is tapped)
    @Published var showWrapped = false
    @Published var showDailyHype = false
    @Published var showGeoPrompt = false
    @Published var geoCheckinPossible = false

    // Profile / admin covers — set by AppHeader, presented by AppRootView's top-level ZStack
    @Published var showMyProfile = false
    @Published var showAdminLogin = false
    @Published var showAdminPanel = false

    // Notification bubble system: passive prompts appear as a glass pill first.
    // Tapping the bubble sets the matching showXxx flag → full-screen overlay.
    // Dismissing advances the queue and shows a replay hint chip.
    @Published var pendingBubble: BubbleNotification?
    @Published var replayHint: ReplayHint?
    private var bubbleQueue: [BubbleNotification] = []

    enum ReplayHint: Equatable { case recap, checkin }

    // Admin mode (password lives in memory only, mirroring the website)
    @Published var adminMode = false
    @Published var adminShowCurrentWeek = false
    var adminPassword: String? {
        get { store.adminPassword }
        set { store.adminPassword = newValue; adminMode = newValue != nil }
    }

    // Check-in ceremony overlays (website: streak-anim / late-anim / chest modal).
    // `afterStreakAnim`/`afterLateAnim` chain the next step like the web's _saNext/_laNext.
    @Published var streakAnimStreak: Int?
    @Published var lateAnimMins: Int?
    @Published var chestResult: ChestResult?
    var afterStreakAnim: (() -> Void)?
    var afterLateAnim: (() -> Void)?

    private var pollingTask: Task<Void, Never>?
    private let store = LocalStore.shared
    private let api = APIClient.shared
    private let cache = GroupDataCache.shared
    private let sync = SyncEngine.shared

    private init() {
        // Restore saved state on launch
        activeGroup = store.activeGroup
        if let g = activeGroup {
            userProfile = store.userProfile(for: g.id)
            // Cold start into a restored group: render cache, sync, poll —
            // same pipeline as enterGroup/switchGroup.
            showCachedDataOrSpinner(for: g.id)
            Task {
                await refreshData()
                isLoading = false
                startPolling()
                runOpeningSequence()
                if !store.notifPrimerSeen { showNotifPrimer = true }
                else { await NotificationManager.shared.requestPermission() }
            }
        }

        sync.$pendingCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$pendingSyncCount)

        ConnectivityMonitor.shared.onReconnect = { [weak self] in
            Task { await self?.refreshData() }
        }
    }

    // MARK: - Group Entry

    func enterGroup(_ group: GroupInfo, profile: UserProfile) async {
        activeGroup = group
        userProfile = profile
        store.activeGroup = group
        store.addGroup(group)
        store.saveUserProfile(profile, for: group.id)

        showCachedDataOrSpinner(for: group.id)
        await refreshData()
        isLoading = false

        startPolling()
        runOpeningSequence()
        if !store.notifPrimerSeen { showNotifPrimer = true }
        else { Task { await NotificationManager.shared.requestPermission() } }
    }

    func switchGroup(_ group: GroupInfo) async {
        stopPolling()
        showWrapped = false; showDailyHype = false; showGeoPrompt = false
        pendingBubble = nil; bubbleQueue = []; replayHint = nil

        activeGroup = group
        store.activeGroup = group
        userProfile = store.userProfile(for: group.id)

        showCachedDataOrSpinner(for: group.id)
        await refreshData()
        isLoading = false

        startPolling()
        runOpeningSequence()
    }

    /// Cache-first: render the last-known data instantly (with pending writes
    /// overlaid); only show a spinner when there is nothing cached yet.
    private func showCachedDataOrSpinner(for groupId: String) {
        if let cached = cache.load(groupId: groupId) {
            groupData = sync.applyPending(to: cached.data)
            isLoading = false
        } else {
            groupData = nil
            isLoading = true
        }
    }

    func leaveCurrentGroup() {
        guard let g = activeGroup else { return }
        stopPolling()
        store.clearUserProfile(for: g.id)
        store.removeGroup(id: g.id)
        cache.remove(groupId: g.id)
        sync.dropPending(for: g.id)

        let remaining = store.allGroups
        if let next = remaining.first {
            activeGroup = next
            store.activeGroup = next
            userProfile = store.userProfile(for: next.id)
            showCachedDataOrSpinner(for: next.id)
            Task {
                await refreshData()
                isLoading = false
            }
        } else {
            activeGroup = nil
            groupData = nil
            userProfile = nil
            store.activeGroup = nil
        }
    }

    // MARK: - Polling

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000) // 8s
                if !Task.isCancelled { await refreshData() }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Single sync pipeline: drain the outbox, fetch fresh data, persist it,
    /// then overlay whatever is still pending. Network failures are silent
    /// when cached data is on screen — the app just flags itself offline.
    func refreshData() async {
        guard let g = activeGroup else { return }

        if ConnectivityMonitor.shared.isOnline, sync.pendingCount > 0 {
            _ = await sync.replayAll()
        }

        do {
            let fresh = try await api.getGroup(id: g.id)
            cache.save(fresh, groupId: g.id)
            groupData = sync.applyPending(to: fresh)
            isOffline = false
            syncCreatorFlag(from: fresh)
        } catch {
            isOffline = error.isNetworkError || !ConnectivityMonitor.shared.isOnline
            if groupData == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func syncCreatorFlag(from data: GroupData) {
        guard let g = activeGroup, let profile = userProfile,
              let me = data.people.first(where: { $0.id == profile.userId }),
              profile.isCreator != me.isCreator else { return }
        userProfile?.isCreator = me.isCreator
        store.saveUserProfile(userProfile!, for: g.id)
    }

    // MARK: - Write facades (offline-capable)

    /// Log an entry; queues it locally when the server is unreachable.
    func logEntry(person: String, date: String, type: String,
                  mins: Int? = nil, reason: String? = nil) async throws -> SyncEngine.SubmitResult {
        guard let g = activeGroup else { throw APIError.notFound }
        let result = try await sync.submitLogEntry(
            groupId: g.id, person: person, date: date, type: type, mins: mins, reason: reason)
        switch result {
        case .synced:
            await refreshData()
            NotificationManager.shared.cancelStreakRiskToday()
        case .queued:
            if var data = groupData {
                data = sync.applyPending(to: data)
                groupData = data
            }
            isOffline = true
        }
        return result
    }

    /// Returns true when synced immediately, false when queued.
    func saveAvailDays(mask: String) async throws -> Bool {
        guard let g = activeGroup, let profile = userProfile else { throw APIError.notFound }
        let synced = try await sync.submitPatchUser(
            groupId: g.id, userId: profile.userId,
            availDays: mask, recoveryCode: profile.recoveryCode)
        if synced { await refreshData() } else { isOffline = true }
        return synced
    }

    /// Returns true when synced immediately, false when queued.
    func saveGymDays(mask: String) async throws -> Bool {
        guard let g = activeGroup, let profile = userProfile else { throw APIError.notFound }
        let synced = try await sync.submitPatchGroup(
            groupId: g.id, gymDays: mask,
            creatorUserId: profile.userId, creatorRecoveryCode: profile.recoveryCode)
        if synced { await refreshData() } else { isOffline = true }
        return synced
    }

    // MARK: - Opening Sequence

    private func runOpeningSequence() {
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

    // MARK: - Streak info & check-in ceremony (website parity)

    /// Website `myStreakInfo()`: my streak plus whether I already extended it today.
    func myStreakInfo() -> (streak: Int, extendedToday: Bool)? {
        guard let profile = userProfile,
              let me = groupData?.people.first(where: { $0.id == profile.userId }) else { return nil }
        let today = dateYMD(Date())
        let extended = (groupData?.entries ?? []).contains {
            $0.person == me.name && $0.date == today && ($0.type == "attend" || $0.type == "late")
        }
        return (me.streak, extended)
    }

    /// Website `computeCheckinLateness()`: ±10-minute window around the fixed
    /// check-in time; nil when the beta feature isn't active for today.
    func computeCheckinLateness() -> (isLate: Bool, minsOff: Int)? {
        guard let data = groupData, data.fixedCheckinEnabled,
              data.checkinTimeDate == dateYMD(Date()),
              let t = data.checkinTime else { return nil }
        let parts = t.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let diff = (now.hour! * 60 + now.minute!) - (parts[0] * 60 + parts[1])
        return (abs(diff) > 10, abs(diff))
    }

    /// Website `finish()` chain after logging a check-in: late-anim → streak-anim
    /// → chest → toast, matching ml-save / submitSelfAttendEntry.
    func runCheckinCeremony(chest: ChestResult?, wasExtended: Bool,
                            lateness: (isLate: Bool, minsOff: Int)?,
                            toast: @escaping (String) -> Void) {
        let info = myStreakInfo()
        let finish = { [weak self] in
            guard let self else { return }
            if let info, !wasExtended {
                if let chest { self.afterStreakAnim = { self.chestResult = chest } }
                self.streakAnimStreak = info.streak
            } else {
                if let chest { self.chestResult = chest }
                if let lateness {
                    toast(lateness.isLate ? K.L.toastLate : K.L.toastOnTime)
                } else {
                    toast(K.L.toastAttendSaved)
                }
            }
        }
        if let lateness, lateness.isLate {
            afterLateAnim = finish
            lateAnimMins = lateness.minsOff
        } else {
            finish()
        }
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
        let radius = Double(data.gymRadius ?? 150)
        store.markGeoPromptSeen(date: today)

        do {
            let loc = try await LocationManager.shared.fetchCurrentLocation()
            let gymCoord = CLLocationCoordinate2D(latitude: gymLat, longitude: gymLng)
            let dist = LocationManager.distance(from: loc.coordinate, to: gymCoord)
            if dist <= radius {
                geoCheckinPossible = true
                showGeoPrompt = true
            }
        } catch {}
    }
}
