import SwiftUI
import MapKit
import CoreLocation

/// Settings (website: #modal-settings) — gym days, fixed check-in time (beta),
/// gym location map, my available days, geo check-in toggle, leave group.
struct SettingsSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.pageDismiss) var dismiss
    @State private var gymDays = Array(repeating: true, count: 7)
    @State private var availDays: [Bool]? = nil
    @State private var isLoading = false
    @State private var toast: String?
    @State private var error = ""

    // Gym location (creator/admin)
    @State private var mapCamera = MapCameraPosition.automatic
    @State private var pin: CLLocationCoordinate2D?
    @State private var radius: Double = 150

    // Geo toggle (all users)
    @State private var geoEnabled = LocalStore.shared.geoEnabled

    // Fixed check-in time (beta, creator/admin)
    @State private var fixedTimeEnabled = false
    @State private var confirmLeave = false
    @State private var showMigrateSheet = false

    // Notification preferences
    @State private var notifReminders = LocalStore.shared.notifReminders
    @State private var notifStreak    = LocalStore.shared.notifStreak
    @State private var notifActivity  = LocalStore.shared.notifActivity
    @State private var reminderTime   = hhmmToDate(LocalStore.shared.reminderTime)
    @State private var quietStart     = hhmmToDate(LocalStore.shared.quietStart)
    @State private var quietEnd       = hhmmToDate(LocalStore.shared.quietEnd)
    @State private var notifMembers: [String]? = LocalStore.shared.notifMembers

    // Launch loading animation
    @State private var loadingStyle = LaunchLoadingView.LoadingStyle(rawValue: LocalStore.shared.loadingStyle) ?? .barbell

    private let dayLabels = K.L.dayNames
    private var isCreatorOrAdmin: Bool {
        appState.userProfile?.isCreator == true || appState.adminMode
    }

    var body: some View {
        NavigationStack {
            Form {
                // Gym days (group, creator only)
                if isCreatorOrAdmin {
                    Section {
                        dayPickerRow(days: $gymDays)
                        Button(K.L.msetGymSave) { Task { await saveGymDays() } }
                            .foregroundColor(K.accentDark)
                    } header: { Text(K.L.msetGymDaysLbl) }

                    // Fixed check-in time (beta)
                    Section {
                        Toggle(K.L.msetFixedtimeToggleLbl, isOn: $fixedTimeEnabled)
                            .tint(K.accentDeep)
                            .onChange(of: fixedTimeEnabled) { _, on in
                                Task { await saveFixedTime(on) }
                            }
                    } header: {
                        HStack(spacing: 6) {
                            Text(K.L.msetFixedtimeLbl)
                            // Outlined/tinted chip — matches web's .beta-badge (lighter
                            // treatment than a filled accent capsule, so "BETA" doesn't
                            // visually compete with primary CTAs).
                            Text("BETA")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(K.accentDark)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(K.accentDeep.opacity(0.12)))
                                .overlay(Capsule().strokeBorder(K.accentDeep.opacity(0.28), lineWidth: 1))
                        }
                    }

                    // Gym location map picker
                    Section {
                        MapReader { proxy in
                            Map(position: $mapCamera) {
                                if let pin {
                                    Marker("Gym", coordinate: pin)
                                        .tint(K.accentDeep)
                                    MapCircle(center: pin, radius: radius)
                                        .foregroundStyle(K.accent.opacity(0.15))
                                        .stroke(K.accentDeep, lineWidth: 1.5)
                                }
                            }
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onTapGesture { screenPoint in
                                if let coord = proxy.convert(screenPoint, from: .local) {
                                    pin = coord
                                }
                            }
                        }
                        HStack {
                            Text(K.L.msetRadiusLbl)
                            Slider(value: $radius, in: 20...500, step: 10)
                                .tint(K.accentDeep)
                            Text("\(Int(radius))m")
                                .font(.system(size: 13, design: .monospaced))
                                .frame(width: 48, alignment: .trailing)
                        }
                        Button(K.L.msetLocateBtn) { Task { await locateMe() } }
                            .foregroundColor(K.accentDark)
                        Button(K.L.msetLocationSave) { Task { await saveLocation() } }
                            .foregroundColor(K.accentDark)
                            .disabled(pin == nil)
                    } header: { Text(K.L.msetLocationLbl) }
                }

                // My available days
                Section {
                    dayPickerRow(days: Binding(
                        get: { availDays ?? Array(repeating: true, count: 7) },
                        set: { availDays = $0 }
                    ))
                    Button(K.L.save) { Task { await saveAvailDays() } }
                        .foregroundColor(K.accentDark)
                } header: { Text(K.L.msetAvailLbl) }

                // Geo check-in toggle (all users)
                Section {
                    Toggle(K.L.msetGeoToggleLbl, isOn: $geoEnabled)
                        .tint(K.accentDeep)
                        .onChange(of: geoEnabled) { _, on in
                            LocalStore.shared.geoEnabled = on
                        }
                    Button(K.L.msetGeoTestBtn) { Task { await testLocation() } }
                        .foregroundColor(K.accentDark)
                } header: { Text(K.L.msetGeoLbl) }

                // Notifications
                Section {
                    Toggle(K.L.msetNotifRemindersLbl, isOn: $notifReminders)
                        .tint(K.accentDeep)
                    if notifReminders {
                        DatePicker(K.L.msetReminderTimeLbl, selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .tint(K.accentDeep)
                    }
                    Toggle(K.L.msetNotifStreakLbl, isOn: $notifStreak)
                        .tint(K.accentDeep)
                    Toggle(K.L.msetNotifActivityLbl, isOn: $notifActivity)
                        .tint(K.accentDeep)
                } header: { Text(K.L.msetNotifLbl) }

                Section {
                    DatePicker(K.L.msetQuietStartLbl, selection: $quietStart, displayedComponents: .hourAndMinute)
                        .tint(K.accentDeep)
                    DatePicker(K.L.msetQuietEndLbl, selection: $quietEnd, displayedComponents: .hourAndMinute)
                        .tint(K.accentDeep)
                } header: { Text(K.L.msetQuietLbl) }

                if notifActivity, let people = appState.groupData?.people.filter({ $0.id != appState.userProfile?.userId }) {
                    Section {
                        ForEach(people, id: \.id) { person in
                            let isOn = Binding<Bool>(
                                get: { notifMembers == nil || notifMembers!.contains(person.id) },
                                set: { on in
                                    var members = notifMembers ?? people.map(\.id)
                                    if on { if !members.contains(person.id) { members.append(person.id) } }
                                    else { members.removeAll { $0 == person.id } }
                                    notifMembers = members.count == people.count ? nil : members
                                }
                            )
                            Toggle(person.name, isOn: isOn).tint(K.accentDeep)
                        }
                    } header: { Text(K.L.msetNotifMembersLbl) }
                }

                Section {
                    Button(K.L.save) { Task { await saveNotifPrefs() } }
                        .foregroundColor(K.accentDark)
                }

                // Account & Login
                Section(K.L.de ? "Konto" : "Account") {
                    if let acc = appState.account {
                        if let email = acc.email { Text(email).foregroundColor(.secondary) }
                        Button(K.L.de ? "Abmelden" : "Sign out") {
                            appState.signOutAccount()
                        }
                        .foregroundColor(K.red)
                    } else {
                        Text(K.L.de
                             ? "Füge E-Mail & Passwort hinzu, damit du deine Gruppen nie verlierst."
                             : "Add email & password so you never lose access to your groups.")
                            .font(.system(size: 13)).foregroundColor(.secondary)
                        Button(K.L.de ? "E-Mail & Passwort einrichten" : "Set email & password") {
                            showMigrateSheet = true
                        }
                        .foregroundColor(K.accentDark)
                    }
                }

                // Launch loading animation
                Section {
                    Picker(K.L.msetLoadingLbl, selection: $loadingStyle) {
                        ForEach(LaunchLoadingView.LoadingStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: loadingStyle) { _, style in
                        LocalStore.shared.loadingStyle = style.rawValue
                    }
                } header: { Text(K.L.msetLoadingLbl) }

                // Leave group
                Section {
                    Button(K.L.leaveGroup, role: .destructive) {
                        confirmLeave = true
                    }
                }

                if !error.isEmpty {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GymBackground())
            .navigationTitle(K.L.msetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .onAppear { loadCurrentValues() }
            .fullScreenCover(isPresented: $showMigrateSheet) {
                MigrationSheet { showMigrateSheet = false }
            }
            .confirmationDialog(K.L.confirmLeave, isPresented: $confirmLeave, titleVisibility: .visible) {
                Button(K.L.leaveGroup, role: .destructive) {
                    appState.leaveCurrentGroup()
                    dismiss()
                }
                Button(K.L.cancel, role: .cancel) {}
            }
            .toast($toast)
        }
    }

    @ViewBuilder
    private func dayPickerRow(days: Binding<[Bool]>) -> some View {
        HStack {
            ForEach(0..<7, id: \.self) { i in
                Button { days.wrappedValue[i].toggle() } label: {
                    Text(dayLabels[i])
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(days.wrappedValue[i] ? K.accent : Color(.secondarySystemFill))
                        .foregroundColor(days.wrappedValue[i] ? K.onAccent : .secondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func loadCurrentValues() {
        if let data = appState.groupData {
            gymDays = data.gymDays.map { $0 == "1" }
            fixedTimeEnabled = data.fixedCheckinEnabled
            if let lat = data.gymLat, let lng = data.gymLng {
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                pin = coord
                radius = Double(data.gymRadius ?? 150)
                mapCamera = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
            }
        }
        if let profile = appState.userProfile,
           let data = appState.groupData,
           let me = data.people.first(where: { $0.id == profile.userId }),
           let ad = me.availDays {
            availDays = ad.map { $0 == "1" }
        }
    }

    private func saveGymDays() async {
        guard gymDays.contains(true) else { error = K.L.errAtLeastOneDay; return }
        let mask = gymDays.map { $0 ? "1" : "0" }.joined()
        isLoading = true
        do {
            let synced = try await appState.saveGymDays(mask: mask)
            toast = synced ? K.L.toastGymDaysSaved : K.L.toastQueuedOffline
        } catch { self.error = error.localizedDescription }
        isLoading = false
    }

    private func saveAvailDays() async {
        let mask = (availDays ?? Array(repeating: true, count: 7)).map { $0 ? "1" : "0" }.joined()
        isLoading = true
        do {
            let synced = try await appState.saveAvailDays(mask: mask)
            toast = synced ? K.L.toastAvailSaved : K.L.toastQueuedOffline
        } catch {
            let desc = error.localizedDescription
            if desc.contains("avail_locked") {
                self.error = K.L.errAvailLocked
            } else {
                self.error = desc
            }
        }
        isLoading = false
    }

    private func saveFixedTime(_ on: Bool) async {
        guard let group = appState.activeGroup, let profile = appState.userProfile else { return }
        do {
            try await APIClient.shared.patchGroup(
                id: group.id, fixedCheckinEnabled: on,
                creatorUserId: profile.userId, creatorRecoveryCode: profile.recoveryCode,
                accountToken: appState.account?.accountToken,
                adminPassword: appState.adminPassword)
            await appState.refreshData()
            toast = on ? K.L.toastFixedCheckinOn : K.L.toastFixedCheckinOff
        } catch {
            fixedTimeEnabled = !on
            self.error = error.localizedDescription
        }
    }

    private func locateMe() async {
        do {
            let loc = try await LocationManager.shared.fetchCurrentLocation()
            pin = loc.coordinate
            mapCamera = .region(MKCoordinateRegion(
                center: loc.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)))
        } catch {
            self.error = K.L.errLocationNotAvailable
        }
    }

    private func saveLocation() async {
        guard let group = appState.activeGroup, let profile = appState.userProfile,
              let pin else { return }
        do {
            try await APIClient.shared.patchGroup(
                id: group.id, gymLat: pin.latitude, gymLng: pin.longitude,
                gymRadius: Int(radius),
                creatorUserId: profile.userId, creatorRecoveryCode: profile.recoveryCode,
                accountToken: appState.account?.accountToken,
                adminPassword: appState.adminPassword)
            await appState.refreshData()
            toast = K.L.toastLocationSaved
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Website mset-geo-test: fetch my position and toast the distance to the gym.
    private func testLocation() async {
        guard let data = appState.groupData,
              let lat = data.gymLat, let lng = data.gymLng else {
            toast = K.L.msetGeoNoLoc
            return
        }
        do {
            let loc = try await LocationManager.shared.fetchCurrentLocation()
            let dist = LocationManager.distance(
                from: loc.coordinate,
                to: CLLocationCoordinate2D(latitude: lat, longitude: lng))
            toast = "📍 \(Int(dist))m"
        } catch {
            toast = K.L.errLocationNotAvailable
        }
    }

    private func saveNotifPrefs() async {
        let store = LocalStore.shared
        store.notifReminders = notifReminders
        store.notifStreak    = notifStreak
        store.notifActivity  = notifActivity
        store.reminderTime   = dateToHHMM(reminderTime)
        store.quietStart     = dateToHHMM(quietStart)
        store.quietEnd       = dateToHHMM(quietEnd)
        store.notifMembers   = notifMembers

        // Reschedule local notifications
        if let data = appState.groupData {
            let me = data.people.first { $0.id == appState.userProfile?.userId }
            NotificationManager.shared.scheduleReminders(
                gymDays: data.gymDays,
                availDays: me?.availDays,
                reminderTime: store.reminderTime)
            if notifStreak { NotificationManager.shared.scheduleStreakRisk(quietStart: store.quietStart) }
        }

        // Sync to server
        guard let g = appState.activeGroup, let p = appState.userProfile else { return }
        let tz = TimeZone.current.identifier
        do {
            try await APIClient.shared.saveNotifPrefs(
                groupId: g.id, userId: p.userId, recoveryCode: p.recoveryCode,
                accountToken: appState.account?.accountToken,
                notifReminders: notifReminders, notifStreak: notifStreak, notifActivity: notifActivity,
                reminderTime: store.reminderTime, quietStart: store.quietStart, quietEnd: store.quietEnd,
                timezone: tz, notifMembers: notifMembers)
            toast = K.L.toastNotifSaved
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - HH:MM ↔ Date helpers (for DatePicker with .hourAndMinute)

private func hhmmToDate(_ hhmm: String) -> Date {
    let parts = hhmm.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 2 else { return Date() }
    var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    c.hour = parts[0]; c.minute = parts[1]
    return Calendar.current.date(from: c) ?? Date()
}

private func dateToHHMM(_ date: Date) -> String {
    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
    return String(format: "%02d:%02d", c.hour ?? 9, c.minute ?? 0)
}
