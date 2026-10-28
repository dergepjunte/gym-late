import SwiftUI

enum AppTab { case week, history, recap, chat, people }

struct AppRootView: View {
    @EnvironmentObject var appState: AppState
    // Screenshot/UI-test hook: SIMCTL_CHILD_GYMLATE_TAB=<tab> picks the start tab
    @State private var selectedTab: AppTab = {
        switch ProcessInfo.processInfo.environment["GYMLATE_TAB"] {
        case "history": return .history
        case "recap":   return .recap
        case "chat":    return .chat
        case "people":  return .people
        default:        return .week
        }
    }()
    @State private var showLogEntry = false
    @State private var showMigrateSheet = false
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

            // Migrate-to-account banner — independent of the opening-sequence
            // bubble above; only shown once that queue has nothing pending,
            // so the two never visually stack in the same screen position.
            if appState.showMigrateBanner, appState.pendingBubble == nil {
                VStack {
                    Spacer()
                    MigrateBannerView(onTap: { showMigrateSheet = true },
                                      onDismiss: { appState.dismissMigrateBanner() })
                        .padding(.horizontal, 16)
                        .padding(.bottom, 84)
                }
                .zIndex(470)
                .transition(.opacity)
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
        .fullScreenCover(isPresented: $showMigrateSheet) {
            MigrationSheet { showMigrateSheet = false }
        }
        // Nur oeffnen, wenn das eigene Profil in den Gruppendaten steht - sonst bliebe eine leere Seite haengen.
        .fullPageCover(isPresented: Binding(get: { appState.showMyProfile && myPerson != nil },
                                            set: { appState.showMyProfile = $0 })) {
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
        .onAppear {
            // Screenshot hook: SIMCTL_CHILD_GYMLATE_HYPE=1 shows the daily hype right away.
            if ProcessInfo.processInfo.environment["GYMLATE_HYPE"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { appState.forceDailyHype() }
            }
            // Screenshot hook: SIMCTL_CHILD_GYMLATE_LOG=1 opens the log-entry page.
            if ProcessInfo.processInfo.environment["GYMLATE_LOG"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showLogEntry = true }
            }
        }
        .onChange(of: appState.openChatRequest) { _, wanted in
            guard wanted else { return }
            appState.openChatRequest = false
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { selectedTab = .chat }
        }
    }

    /// iOS 18+: native TabView. On iOS 26 this renders the floating Liquid
    /// Glass bar — the glass pill grows on touch and tracks the finger,
    /// exactly like Apple Music. No custom animation code needed.
    @available(iOS 18.0, *)
    private var nativeTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(K.L.navHome, systemImage: "dumbbell.fill", value: AppTab.week) {
                WeekView(showLogEntry: $showLogEntry, toast: $toast)
                    .screenEntrance()
                    .background(GymBackground().ignoresSafeArea())
            }
            Tab(K.L.navHistory, systemImage: "calendar", value: AppTab.history) {
                HistoryView()
                    .screenEntrance()
                    .background(GymBackground().ignoresSafeArea())
            }
            Tab(K.L.navRecap, systemImage: "trophy.fill", value: AppTab.recap) {
                RecapView()
                    .screenEntrance()
                    .background(GymBackground().ignoresSafeArea())
            }
            Tab(K.L.navChat, systemImage: "bubble.left.and.bubble.right.fill", value: AppTab.chat) {
                ChatView()
                    .screenEntrance()
                    .background(GymBackground().ignoresSafeArea())
            }
            Tab(K.L.navPeople, systemImage: "figure.strengthtraining.traditional", value: AppTab.people) {
                PeopleView()
                    .screenEntrance()
                    .background(GymBackground().ignoresSafeArea())
            }
        }
        .tint(K.accent)
    }

    private static let tabTransition = AnyTransition.asymmetric(
        insertion: .opacity.combined(with: .scale(scale: 0.97)).combined(with: .offset(y: 14)),
        removal: .opacity.combined(with: .scale(scale: 1.02)))

    /// iOS 17 fallback: previous custom glass bar with the yellow sliding pill.
    private var legacyTabLayout: some View {
        ZStack {
            switch selectedTab {
            case .week:    WeekView(showLogEntry: $showLogEntry, toast: $toast).transition(Self.tabTransition)
            case .history: HistoryView().transition(Self.tabTransition)
            case .recap:   RecapView().transition(Self.tabTransition)
            case .chat:    ChatView().transition(Self.tabTransition)
            case .people:  PeopleView().transition(Self.tabTransition)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: selectedTab)
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
