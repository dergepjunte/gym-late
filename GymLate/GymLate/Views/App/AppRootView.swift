import SwiftUI

enum AppTab { case week, history, recap, people }

struct AppRootView: View {
    @EnvironmentObject var appState: AppState
    // Screenshot/UI-test hook: SIMCTL_CHILD_GYMLATE_TAB=<tab> picks the start tab
    @State private var selectedTab: AppTab = {
        switch ProcessInfo.processInfo.environment["GYMLATE_TAB"] {
        case "history": return .history
        case "recap":   return .recap
        case "people":  return .people
        default:        return .week
        }
    }()
    @State private var showLogEntry = false
    @State private var toast: String?

    private var myPerson: Person? {
        guard let profile = appState.userProfile else { return nil }
        return appState.groupData?.people.first { $0.id == profile.userId }
    }

    var body: some View {
        ZStack {
            GymBackground().ignoresSafeArea()

            Group {
                if #available(iOS 18.0, *) {
                    nativeTabView
                } else {
                    legacyTabLayout
                }
            }

            // Overlays
            if appState.showWrapped {
                WrappedView { appState.onWrappedDismissed() }
                    .zIndex(500)
            }
            if appState.showDailyHype {
                DailyHypeView { appState.onHypeDismissed() }
                    .zIndex(500)
            }
            if appState.showGeoPrompt {
                GeoPromptView { Task { await doGeoCheckin() } }
                    .zIndex(500)
            }
            // Notification bubble (opening-sequence prompts: Wrapped / Hype / Geo)
            // Floats above the tab bar; zIndex below ceremony overlays.
            if let bubble = appState.pendingBubble {
                VStack {
                    Spacer()
                    NotificationBubbleView(bubble: bubble) {
                        appState.onBubbleTapped()
                    } onDismiss: {
                        appState.onBubbleDismissed()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 84)
                }
                .zIndex(480)
                .transition(
                    UIAccessibility.isReduceMotionEnabled
                        ? .opacity
                        : .move(edge: .bottom).combined(with: .opacity)
                )
                .id(bubble.id)
            }

            // Replay hint chip (shown after bubble dismiss)
            if let hint = appState.replayHint {
                VStack {
                    Spacer()
                    ReplayHintChip(hint: hint) { appState.replayHint = nil }
                        .padding(.bottom, 84)
                }
                .zIndex(479)
                .transition(.opacity)
            }

            // Notification priming (one-time, cannot be dismissed by backdrop)
            if appState.showNotifPrimer {
                NotifPrimerView()
                    .zIndex(510)
            }

            // Check-in ceremony (website: late-anim → streak-anim → chest)
            if let mins = appState.lateAnimMins {
                LateAnimView(minsOff: mins) {
                    appState.lateAnimMins = nil
                    let next = appState.afterLateAnim; appState.afterLateAnim = nil
                    next?()
                }
                .zIndex(600)
            }
            if let streak = appState.streakAnimStreak {
                StreakAnimView(newStreak: streak) {
                    appState.streakAnimStreak = nil
                    let next = appState.afterStreakAnim; appState.afterStreakAnim = nil
                    next?()
                }
                .zIndex(610)
            }
            if let chest = appState.chestResult {
                ChestView(chest: chest) { appState.chestResult = nil }
                    .zIndex(620)
            }
        }
        .fullPageCover(isPresented: $showLogEntry) { LogEntrySheet(toast: $toast) }
        .fullPageCover(isPresented: $appState.showMyProfile) {
            if let me = myPerson { ProfileView(person: me) }
        }
        .fullPageCover(isPresented: $appState.showAdminLogin) { AdminLoginSheet(toast: $toast) }
        .onChange(of: appState.adminMode) { _, isAdmin in if isAdmin { appState.showAdminPanel = true } }
        .fullPageCover(isPresented: $appState.showAdminPanel) { AdminPanelPage() }
        .onReceive(SyncEngine.shared.$syncErrorMessage) { msg in
            if let msg {
                toast = msg
                SyncEngine.shared.syncErrorMessage = nil
            }
        }
        .toast($toast)
    }

    /// iOS 18+: native TabView. On iOS 26 this renders the floating Liquid
    /// Glass bar — the glass pill grows on touch and tracks the finger,
    /// exactly like Apple Music. No custom animation code needed.
    @available(iOS 18.0, *)
    private var nativeTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(K.L.navHome, systemImage: "house.fill", value: AppTab.week) {
                WeekView(showLogEntry: $showLogEntry, toast: $toast)
                    .background(GymBackground().ignoresSafeArea())
            }
            Tab(K.L.navHistory, systemImage: "calendar.badge.clock", value: AppTab.history) {
                HistoryView()
                    .background(GymBackground().ignoresSafeArea())
            }
            Tab(K.L.navRecap, systemImage: "chart.bar.fill", value: AppTab.recap) {
                RecapView()
                    .background(GymBackground().ignoresSafeArea())
            }
            Tab(K.L.navPeople, systemImage: "person.2.fill", value: AppTab.people) {
                PeopleView()
                    .background(GymBackground().ignoresSafeArea())
            }
        }
        .tint(K.accentDeep)
    }

    /// iOS 17 fallback: previous custom glass bar with the yellow sliding pill.
    private var legacyTabLayout: some View {
        ZStack {
            switch selectedTab {
            case .week:    WeekView(showLogEntry: $showLogEntry, toast: $toast)
            case .history: HistoryView()
            case .recap:   RecapView()
            case .people:  PeopleView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Floating glass bar: content scrolls underneath it.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNav(selected: $selectedTab)
        }
    }

    private func doGeoCheckin() async {
        guard let profile = appState.userProfile else { return }
        appState.showGeoPrompt = false
        let lateness = appState.computeCheckinLateness()
        let wasExtended = appState.myStreakInfo()?.extendedToday ?? false
        do {
            let today = dateYMD(Date())
            let result = try await appState.logEntry(
                person: profile.name, date: today,
                type: (lateness?.isLate == true) ? "late" : "attend",
                mins: (lateness?.isLate == true) ? lateness?.minsOff : nil)
            switch result {
            case .synced(let resp):
                appState.runCheckinCeremony(chest: resp.chest, wasExtended: wasExtended,
                                            lateness: lateness) { toast = $0 }
            case .queued:
                toast = K.L.toastQueuedOffline
            }
        } catch {
            toast = K.L.errServer
        }
    }
}
