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
    // Cold-start loading screen (LaunchLoadingView) — shown briefly on every
    // launch for the branded splash, independent of any network refresh.
    @Published var isBootLoading = false
    // Netflix-style launch picker (website: #screen-profile-picker) — true on
    // cold start whenever ≥1 group is saved locally; set false once a saved
    // profile is tapped (switchGroup) or the user chooses "+" to add a new one.
    @Published var showLaunchPicker = false

    // Global account (email/password + Apple/Google SSO). nil = this device
    // only has legacy per-group recovery-code profiles (or is brand new).
    @Published var account: AccountInfo?
    // Persistent "secure your account" nudge, independent of the one-shot
    // opening-sequence bubbles — shown while there's a legacy profile with a
    // recovery code but no linked account, until dismissed.
    @Published var showMigrateBanner = false

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
    var bubbleQueue: [BubbleNotification] = []

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
    let store = LocalStore.shared
    private let api = APIClient.shared
    private let cache = GroupDataCache.shared
    private let sync = SyncEngine.shared

    private init() {
        account = store.account
        refreshMigrateBanner()

        // Legacy single-group installs (pre-multi-group `gymGroups` key) get
        // backfilled so they still get a pickable entry instead of losing
        // access to their group (website: init.js legacy backfill).
        if store.allGroups.isEmpty, let legacy = store.activeGroup {
            store.addGroup(legacy)
        }

        // Netflix-style launch picker (website: init.js cold-start logic) —
        // show the branded splash briefly, then either "Wer trainiert?" (≥1
        // saved group) or the classic landing screen. Cold start no longer
        // silently re-enters the last-active group: `activeGroup`/`userProfile`
        // stay nil until a saved profile is tapped (see switchGroup).
        isBootLoading = true
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            showLaunchPicker = !store.allGroups.isEmpty
            withAnimation(.easeInOut(duration: 0.4)) { isBootLoading = false }
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
        refreshMigrateBanner()
    }

    func switchGroup(_ group: GroupInfo) async {
        // Dismiss the launch picker (website: switchToGroup clears the picker
        // screen too) — no-op if already dismissed, e.g. when called from the
        // in-app GroupSwitcherSheet rather than the cold-start picker.
        showLaunchPicker = false

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
        // Website's updated switchToGroup now runs the full enter-group
        // ceremony (cold start no longer does this automatically) — mirror
        // that here so it matches enterGroup's behavior.
        if !store.notifPrimerSeen { showNotifPrimer = true }
        else { Task { await NotificationManager.shared.requestPermission() } }
        refreshMigrateBanner()
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
            availDays: mask, recoveryCode: profile.recoveryCode,
            accountToken: account?.accountToken)
        if synced { await refreshData() } else { isOffline = true }
        return synced
    }

    /// Returns true when synced immediately, false when queued.
    func saveGymDays(mask: String) async throws -> Bool {
        guard let g = activeGroup, let profile = userProfile else { throw APIError.notFound }
        let synced = try await sync.submitPatchGroup(
            groupId: g.id, gymDays: mask,
            creatorUserId: profile.userId, creatorRecoveryCode: profile.recoveryCode,
            accountToken: account?.accountToken)
        if synced { await refreshData() } else { isOffline = true }
        return synced
    }

    // MARK: - Global Account (email/password + Apple/Google SSO)

    private func saveAccount(_ info: AccountInfo) {
        account = info
        store.account = info
        showMigrateBanner = false
    }

    func signOutAccount() {
        account = nil
        store.account = nil
    }

    func registerAccount(email: String, password: String) async throws {
        let info = try await api.registerAccount(email: email, password: password)
        saveAccount(info)
    }

    func loginAccount(email: String, password: String) async throws {
        let info = try await api.loginAccount(email: email, password: password)
        saveAccount(info)
        await applyAccountGroups(info)
    }

    func appleSignIn(identityToken: String, email: String?) async throws {
        let info = try await api.appleSignIn(identityToken: identityToken, email: email)
        saveAccount(info)
        await applyAccountGroups(info)
    }

    func googleSignIn(identityToken: String) async throws {
        let info = try await api.googleSignIn(identityToken: identityToken)
        saveAccount(info)
        await applyAccountGroups(info)
    }

    /// Fetch every group linked to this account and repopulate local state —
    /// what lets a sign-in on a brand-new device (or right after migrating)
    /// restore all groups with zero recovery codes involved.
    func applyAccountGroups(_ info: AccountInfo) async {
        guard let resp = try? await api.accountGroups(accountToken: info.accountToken) else { return }
        for g in resp.groups {
            let groupInfo = GroupInfo(id: g.id, code: g.code, name: g.name)
            store.addGroup(groupInfo)
            store.saveUserProfile(g.profile, for: g.id)
        }
        // Enter the first linked group if we don't already have one active.
        if activeGroup == nil, let first = resp.groups.first {
            let groupInfo = GroupInfo(id: first.id, code: first.code, name: first.name)
            await enterGroup(groupInfo, profile: first.profile)
        }
    }

    /// The migration entry point: link every locally-known recovery-code
    /// profile to `account` in one call, so a person in multiple groups
    /// migrates all of them from a single popup visit.
    func migrateLinkAll() async {
        guard let acc = account else { return }
        let links = store.migratableGroupLinks
        guard !links.isEmpty else { return }
        guard let resp = try? await api.linkRecovery(accountToken: acc.accountToken, links: links) else { return }
        guard !resp.linked.isEmpty else { return }
        // Refresh every migrated profile so its local recoveryCode clears —
        // future writes switch to the accountToken path automatically.
        await applyAccountGroups(acc)
        if let g = activeGroup, resp.linked.contains(g.id) {
            userProfile = store.userProfile(for: g.id)
        }
        showMigrateBanner = false
    }

    /// Re-evaluate whether the "secure your account" banner should show.
    /// Deliberately intrusive: true every time this device holds a legacy
    /// recovery-code profile with no linked account — NOT a one-time nag.
    /// Dismissing only clears it for the current view; it returns on the
    /// next enterGroup (app open / group switch) until the user migrates.
    func refreshMigrateBanner() {
        showMigrateBanner = account == nil && !store.migratableGroupLinks.isEmpty
    }

    func dismissMigrateBanner() {
        showMigrateBanner = false
    }
}
