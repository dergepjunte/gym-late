import Foundation
import Combine
import CoreLocation

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

    // Opening sequence overlays
    @Published var showWrapped = false
    @Published var showDailyHype = false
    @Published var showGeoPrompt = false
    @Published var geoCheckinPossible = false

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
    }

    func switchGroup(_ group: GroupInfo) async {
        stopPolling()
        showWrapped = false; showDailyHype = false; showGeoPrompt = false

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

        // 3. Geo: handled async in AppRootView after hype
        _ = group // referenced to avoid unused warning

        if shouldShowWrapped {
            store.markWrappedSeen(weekStart: weekStart)
            showWrapped = true
        } else if shouldShowHype {
            store.markDailyHypeSeen(date: today)
            showDailyHype = true
        }
        // geo prompt triggered from AppRootView after hype dismissal
    }

    func onHypeDismissed() {
        showDailyHype = false
        Task { await checkGeoPrompt() }
    }

    func onWrappedDismissed() {
        showWrapped = false
        let today = dateYMD(Date())
        let cal = Calendar.iso8601UTC
        let gymDays = groupData?.gymDays ?? ""
        let dayOfWeek = cal.component(.weekday, from: Date())
        let idx = dayOfWeek == 1 ? 6 : dayOfWeek - 2
        let todayScheduled = gymDays.count == 7 && Array(gymDays)[idx] == "1"
        if todayScheduled && !store.isDailyHypeSeen(date: today) {
            store.markDailyHypeSeen(date: today)
            showDailyHype = true
        } else {
            Task { await checkGeoPrompt() }
        }
    }

    private func checkGeoPrompt() async {
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
