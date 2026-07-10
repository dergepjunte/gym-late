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
    @State private var showSettings = false
    @State private var showGroupSwitcher = false
    @State private var showMyProfile = false
    @State private var showAdminLogin = false
    @State private var toast: String?

    var body: some View {
        ZStack {
            GymBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                AppHeader(
                    onSettings: { showSettings = true },
                    onMyProfile: { showMyProfile = true },
                    onAdminUnlock: { showAdminLogin = true },
                    onSwitchGroup: { showGroupSwitcher = true },
                    toast: $toast
                )

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
                    .padding(.bottom, 100)
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
                        .padding(.bottom, 100)
                }
                .zIndex(479)
                .transition(.opacity)
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
        .fullPageCover(isPresented: $showSettings) { SettingsSheet() }
        .fullPageCover(isPresented: $showGroupSwitcher) { GroupSwitcherSheet() }
        .fullPageCover(isPresented: $showMyProfile) {
            if let me = myPerson { ProfileView(person: me) }
        }
        .fullPageCover(isPresented: $showAdminLogin) { AdminLoginSheet(toast: $toast) }
        .onReceive(SyncEngine.shared.$syncErrorMessage) { msg in
            if let msg {
                toast = msg
                SyncEngine.shared.syncErrorMessage = nil
            }
        }
        .toast($toast)
    }

    private var myPerson: Person? {
        guard let profile = appState.userProfile else { return nil }
        return appState.groupData?.people.first { $0.id == profile.userId }
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

// MARK: - Header (website: 🏋️ GymLate · gear · avatar, group pill below)

struct AppHeader: View {
    @EnvironmentObject var appState: AppState
    let onSettings: () -> Void
    let onMyProfile: () -> Void
    let onAdminUnlock: () -> Void
    let onSwitchGroup: () -> Void
    @Binding var toast: String?

    @State private var logoTaps = 0
    @State private var lastTap = Date.distantPast

    var body: some View {
        VStack(spacing: 8) {
            // Title row
            ZStack {
                HStack(spacing: 8) {
                    // 5× tap on the logo unlocks admin, like the website
                    Text("🏋️")
                        .font(.system(size: 24))
                        .onTapGesture { registerLogoTap() }
                    Text(K.L.appName)
                        .font(Theme.heading(20))
                    if appState.adminMode {
                        Text("ADMIN")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(K.onAccent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(K.accent))
                    }
                }

                HStack(spacing: 8) {
                    Spacer()
                    if appState.pendingSyncCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("\(appState.pendingSyncCount)")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(K.accentDeep)
                    } else if appState.isOffline {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Button { onSettings() } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                            .frame(width: 34, height: 34)
                            .glassCard(radius: 17)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(K.L.de ? "Einstellungen" : "Settings")
                    Button { onMyProfile() } label: {
                        AvatarView(emoji: appState.userProfile?.avatarEmoji ?? "🏋️",
                                   color: appState.userProfile?.avatarColor ?? "#7c3aed",
                                   img: appState.userProfile?.avatarImg,
                                   size: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(K.L.de ? "Mein Profil" : "My profile")
                }
            }
            .padding(.horizontal, 16)

            // Group pill: [switch] name · CODE (tap to copy)
            HStack(spacing: 8) {
                if LocalStore.shared.allGroups.count > 1 {
                    Button { onSwitchGroup() } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(K.amberText)
                    }
                    .buttonStyle(.plain)
                }
                Text(appState.groupData?.name ?? "")
                    .font(Theme.body(14, .bold))
                    .lineLimit(1)
                Text("·").foregroundColor(.secondary)
                Button {
                    UIPasteboard.general.string = appState.groupData?.code ?? ""
                    toast = K.L.toastCopied
                    hapticSuccess()
                } label: {
                    Text(appState.groupData?.code ?? "")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .kerning(2)
                        .foregroundColor(K.amberText)
                }
                .buttonStyle(.plain)
                Text(K.L.pillHint)
                    .font(Theme.body(10))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16).padding(.vertical, 9)
            .glassCard(radius: 22)
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func registerLogoTap() {
        let now = Date()
        if now.timeIntervalSince(lastTap) > 2 { logoTaps = 0 }
        lastTap = now
        logoTaps += 1
        if logoTaps >= 5 {
            logoTaps = 0
            if appState.adminMode {
                appState.adminPassword = nil
                toast = K.L.toastAdmOut
            } else {
                onAdminUnlock()
            }
            haptic(.medium)
        }
    }
}

// MARK: - Bottom Nav (iOS 17 fallback)

/// Floating Liquid Glass capsule bar. On iOS 26 it uses the real glassEffect;
/// earlier systems fall back to the shared glass recipe. The selected tab
/// carries a yellow gradient pill that slides between items.
struct BottomNav: View {
    @Binding var selected: AppTab
    @Namespace private var pillNS

    var body: some View {
        HStack(spacing: 2) {
            navItem(.week, icon: "house.fill", label: K.L.navHome)
            navItem(.history, icon: "calendar.badge.clock", label: K.L.navHistory)
            navItem(.recap, icon: "chart.bar.fill", label: K.L.navRecap)
            navItem(.people, icon: "person.2.fill", label: K.L.navPeople)
        }
        .padding(5)
        .background(NavGlassCapsule())
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func navItem(_ tab: AppTab, icon: String, label: String) -> some View {
        let isSelected = selected == tab
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { selected = tab }
            haptic(.light)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                Text(label)
                    .font(Theme.body(10, .bold))
            }
            .foregroundColor(isSelected ? K.onAccent : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    Capsule()
                        .fill(LinearGradient(colors: Theme.accentGradient,
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(
                            Capsule().fill(LinearGradient(
                                stops: [.init(color: .white.opacity(0.40), location: 0),
                                        .init(color: .clear, location: 0.5)],
                                startPoint: .top, endPoint: .bottom))
                        )
                        .matchedGeometryEffect(id: "navPill", in: pillNS)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Capsule-shaped Liquid Glass base for the floating nav bar.
private struct NavGlassCapsule: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let g = Theme.Glass.tokens(for: scheme)
        Group {
            if #available(iOS 26.0, *) {
                Color.clear.glassEffect(.regular.interactive(), in: .capsule)
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .overlay(
            Capsule().fill(LinearGradient(
                stops: [.init(color: g.sheen, location: 0),
                        .init(color: .clear, location: 0.45)],
                startPoint: .topLeading, endPoint: .bottom))
            .allowsHitTesting(false)
        )
        .overlay(
            Capsule().strokeBorder(LinearGradient(
                colors: [g.borderTop, g.border],
                startPoint: .top, endPoint: .bottom), lineWidth: 1)
            .allowsHitTesting(false)
        )
        .shadow(color: g.shadow, radius: 16, x: 0, y: 8)
    }
}
