import SwiftUI

enum AppTab { case week, history, recap, people }

struct AppRootView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AppTab = .week
    @State private var showLogEntry = false
    @State private var showSettings = false
    @State private var showGroupSwitcher = false
    @State private var toast: String?

    var body: some View {
        ZStack {
            GymBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // Group pill header
                GroupPillHeader(
                    onSettings: { showSettings = true },
                    onSwitchGroup: { showGroupSwitcher = true }
                )

                // Tab content
                ZStack {
                    switch selectedTab {
                    case .week:    WeekView(showLogEntry: $showLogEntry, toast: $toast)
                    case .history: HistoryView()
                    case .recap:   RecapView()
                    case .people:  PeopleView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                BottomNav(selected: $selectedTab)
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
        }
        .sheet(isPresented: $showLogEntry) { LogEntrySheet(toast: $toast) }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .sheet(isPresented: $showGroupSwitcher) { GroupSwitcherSheet() }
        .onReceive(SyncEngine.shared.$syncErrorMessage) { msg in
            if let msg {
                toast = msg
                SyncEngine.shared.syncErrorMessage = nil
            }
        }
        .toast($toast)
    }

    private func doGeoCheckin() async {
        guard let profile = appState.userProfile else { return }
        appState.showGeoPrompt = false
        do {
            let today = dateYMD(Date())
            let result = try await appState.logEntry(person: profile.name,
                                                     date: today, type: "attend")
            if case .queued = result {
                toast = "Offline gespeichert – wird synchronisiert ✓"
            } else {
                toast = K.L.attend + " ✓"
            }
        } catch {
            toast = K.L.errServer
        }
    }
}

// MARK: - Group Pill Header

struct GroupPillHeader: View {
    @EnvironmentObject var appState: AppState
    let onSettings: () -> Void
    let onSwitchGroup: () -> Void

    var body: some View {
        HStack {
            Button { onSwitchGroup() } label: {
                HStack(spacing: 6) {
                    Text(appState.groupData?.code ?? "")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(K.accentDark)
                    if LocalStore.shared.allGroups.count > 1 {
                        Image(systemName: "chevron.down.circle.fill")
                            .foregroundColor(K.accentDark).font(.system(size: 14))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .glassCard(radius: 20)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 6) {
                Text(appState.groupData?.name ?? "")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
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
            }

            Spacer()

            Button { onSettings() } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Bottom Nav

struct BottomNav: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack {
            NavItem(tab: .week, icon: "calendar.badge.clock", label: K.L.navWeek, selected: $selected)
            NavItem(tab: .history, icon: "clock.arrow.circlepath", label: K.L.navHistory, selected: $selected)
            NavItem(tab: .recap, icon: "star.fill", label: K.L.navRecap, selected: $selected)
            NavItem(tab: .people, icon: "person.3.fill", label: K.L.navPeople, selected: $selected)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4 + (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0))
        .background(NavGlassBar())
    }
}

/// Glass treatment for the full-width bottom nav bar: material base,
/// gloss sheen and a brighter top hairline instead of a plain Divider.
private struct NavGlassBar: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let g = Theme.Glass.tokens(for: scheme)
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                LinearGradient(
                    stops: [.init(color: g.sheen.opacity(0.5), location: 0),
                            .init(color: .clear, location: 0.45)],
                    startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            )
            .overlay(alignment: .top) {
                g.borderTop.frame(height: 1).allowsHitTesting(false)
            }
            .ignoresSafeArea(edges: .bottom)
    }
}

struct NavItem: View {
    let tab: AppTab
    let icon: String
    let label: String
    @Binding var selected: AppTab

    var isSelected: Bool { selected == tab }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25)) { selected = tab }
            haptic(.light)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: isSelected ? 20 : 18))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isSelected ? K.accentDeep : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
