import SwiftUI

/// Admin panel — full-page Shortcuts-style grid of action tiles.
/// Opened after admin login via AppRootView's fullPageCover.
struct AdminPanelPage: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.pageDismiss) private var dismiss
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Test data
                    Text(K.L.admSectionData).eyebrow()
                        .padding(.horizontal, 4).padding(.top, 8).padding(.bottom, 10)

                    AdminTileGrid {
                        AdminTile(
                            symbol: "plus.circle.fill",
                            color: K.accentDeep,
                            label: K.L.admAdd
                        ) { Task { await addTestData() } }
                        AdminTile(
                            symbol: "trash.fill",
                            color: K.red,
                            label: K.L.admDel
                        ) { Task { await deleteTestData() } }
                    }

                    // MARK: Ceremonies
                    Text(K.L.admSectionCeremonies).eyebrow()
                        .padding(.horizontal, 4).padding(.top, 24).padding(.bottom, 10)

                    AdminTileGrid {
                        AdminTile(
                            symbol: "arrow.counterclockwise",
                            color: K.accentDeep,
                            label: K.L.admReplay
                        ) { appState.replayWrapped() }
                        AdminTile(
                            symbol: "sparkles",
                            color: K.green,
                            label: K.L.admForceHype
                        ) { appState.forceDailyHype() }
                        AdminTile(
                            symbol: "location.fill",
                            color: Color(hex: "#0891b2"),
                            label: K.L.admForceGeo
                        ) { appState.forceGeoPrompt() }
                        AdminTile(
                            symbol: appState.adminShowCurrentWeek ? "calendar.badge.minus" : "calendar.badge.plus",
                            color: K.gold,
                            label: appState.adminShowCurrentWeek ? K.L.admWeekOff : K.L.admWeekOn
                        ) { appState.adminShowCurrentWeek.toggle() }
                        AdminTile(
                            symbol: "flag.slash",
                            color: K.gold,
                            label: K.L.admClearFlags
                        ) {
                            appState.clearTodayFlags()
                            toast = "✓"
                        }
                    }

                    // MARK: Notifications (10s delay)
                    Text(K.L.admSectionNotif).eyebrow()
                        .padding(.horizontal, 4).padding(.top, 24).padding(.bottom, 10)

                    AdminTileGrid {
                        AdminTile(
                            symbol: "bell.fill",
                            color: Color(hex: "#6366f1"),
                            label: K.L.admTestReminder
                        ) { Task { await testNotif("reminder") } }
                        AdminTile(
                            symbol: "flame.fill",
                            color: Color(hex: "#f97316"),
                            label: K.L.admTestStreak
                        ) { Task { await testNotif("streak") } }
                        AdminTile(
                            symbol: "person.2.fill",
                            color: Color(hex: "#14b8a6"),
                            label: K.L.admTestActivity
                        ) { Task { await testNotif("activity") } }
                        AdminTile(
                            symbol: "bell.badge.fill",
                            color: Color(hex: "#8b5cf6"),
                            label: K.L.admTestAll
                        ) { Task { await testNotif("all") } }
                    }

                    if let coords = gymCoords {
                        Text(coords)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.top, 16)
                            .padding(.horizontal, 4)
                    }

                    // Exit
                    Button {
                        appState.adminPassword = nil
                        toast = K.L.toastAdmOut
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { dismiss() }
                    } label: {
                        Text(K.L.admExit)
                            .font(Theme.body(14, .bold))
                            .foregroundColor(K.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(K.red.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(K.red.opacity(0.30), lineWidth: 1.5)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 28)

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .scrollContentBackground(.hidden)
            .background(GymBackground())
            .navigationTitle(K.L.admTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
        }
        .toast($toast)
    }

    // MARK: - Helpers

    private var gymCoords: String? {
        guard let lat = appState.groupData?.gymLat,
              let lng = appState.groupData?.gymLng,
              let r   = appState.groupData?.gymRadius else { return nil }
        return String(format: "Gym: %.5f, %.5f — %dm", lat, lng, r)
    }

    private func testNotif(_ type: String) async {
        await NotificationManager.shared.sendTestNotification(type: type)
        toast = K.L.toastTestScheduled
    }

    private func addTestData() async {
        guard let group = appState.activeGroup,
              let people = appState.groupData?.people, !people.isEmpty else {
            toast = K.L.noPeople; return
        }
        let cal = Calendar.iso8601UTC
        let lastMon = cal.date(byAdding: .weekOfYear, value: -1, to: cal.startOfWeek(for: Date()))!
        do {
            for person in people.prefix(4) {
                let day = cal.date(byAdding: .day, value: Int.random(in: 0...5), to: lastMon)!
                let kind = ["late", "late", "attend", "skip"].randomElement()!
                _ = try await APIClient.shared.logEntry(
                    groupId: group.id, person: person.name, date: dateYMD(day),
                    type: kind, mins: kind == "late" ? Int.random(in: 5...45) : nil,
                    reason: kind == "skip" ? "rest" : nil)
            }
            await appState.refreshData()
            toast = K.L.toastAdded
        } catch {
            toast = K.L.errServer
        }
    }

    private func deleteTestData() async {
        toast = "✓"
    }
}

// MARK: - Reusable tile components

/// 2-column grid wrapper
struct AdminTileGrid<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            content
        }
    }
}

/// Single Shortcuts-style tile: coloured SF Symbol glyph + label below
struct AdminTile: View {
    let symbol: String
    let color: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
            haptic(.light)
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(color.opacity(0.14))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(color)
                    )
                Text(label)
                    .font(Theme.body(12, .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14).padding(.horizontal, 12)
            .glassCard(radius: 16)
        }
        .buttonStyle(.plain)
    }
}
