import SwiftUI
import MapKit
import CoreLocation

/// Settings (website: #modal-settings) — gym days, fixed check-in time (beta),
/// gym location map, my available days, geo check-in toggle, leave group.
struct SettingsSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
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
                            Text("BETA")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(K.onAccent)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(K.accent))
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

                // Leave group
                Section {
                    Button(K.L.leaveGroup, role: .destructive) {
                        appState.leaveCurrentGroup()
                        dismiss()
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
                ToolbarItem(placement: .confirmationAction) {
                    Button(K.L.close) { dismiss() }
                }
            }
            .onAppear { loadCurrentValues() }
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
}
