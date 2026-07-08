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
            }
            // Floating glass bar: content scrolls underneath it.
            .safeAreaInset(edge: .bottom, spacing: 0) {
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
                        .foregroundColor(K.amberText)
                    if LocalStore.shared.allGroups.count > 1 {
                        Image(systemName: "chevron.down.circle.fill")
                            .foregroundColor(K.amberText).font(.system(size: 14))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .glassCard(radius: 20)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 6) {
                Text(appState.groupData?.name ?? "")
                    .font(Theme.heading(15))
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

/// Floating Liquid Glass capsule bar. On iOS 26 it uses the real glassEffect;
/// earlier systems fall back to the shared glass recipe. The selected tab
/// carries a yellow gradient pill that slides between items.
struct BottomNav: View {
    @Binding var selected: AppTab
    @Namespace private var pillNS

    var body: some View {
        HStack(spacing: 2) {
            navItem(.week, icon: "calendar.badge.clock", label: K.L.navWeek)
            navItem(.history, icon: "clock.arrow.circlepath", label: K.L.navHistory)
            navItem(.recap, icon: "star.fill", label: K.L.navRecap)
            navItem(.people, icon: "person.3.fill", label: K.L.navPeople)
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
        .shadow(color: g.shadow, radius: 20, x: 0, y: 10)
    }
}
