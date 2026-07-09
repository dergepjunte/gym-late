import SwiftUI

/// Daily gym-day hype (website: #daily-hype) — incl. the fixed check-in time
/// section: whoever opens the app first sets today's time; afterwards the
/// time and the ±10-minute window are displayed.
struct DailyHypeView: View {
    let onDismiss: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    @State private var pickedTime: Date = {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 18; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()
    @State private var saving = false

    private var fixedTimeActive: Bool { appState.groupData?.fixedCheckinEnabled == true }
    private var todaysTime: String? {
        guard let d = appState.groupData, d.checkinTimeDate == dateYMD(Date()) else { return nil }
        return d.checkinTime
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: Theme.hype,
                startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Text("🏋️")
                    .font(.system(size: 100))
                    .scaleEffect(scale)

                VStack(spacing: 12) {
                    Text(K.L.de ? "Heute ist Gym-Tag!" : "Today is Gym Day!")
                        .font(.system(size: 34, weight: .black))
                        .foregroundColor(.white)
                    Text(K.L.de ? "Zeig, was du drauf hast. 💪" : "Show them what you've got. 💪")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }

                // Fixed check-in time (beta): set or display today's time
                if fixedTimeActive {
                    if let time = todaysTime {
                        VStack(spacing: 4) {
                            Text(K.L.de ? "Heutige Uhrzeit" : "Today's time")
                                .font(.system(size: 13)).foregroundColor(.white.opacity(0.7))
                            Text(time)
                                .font(.system(size: 30, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                            Text(K.L.dhTimeWindowHint(time))
                                .font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.14).cornerRadius(16))
                    } else {
                        VStack(spacing: 8) {
                            Text(K.L.de ? "Uhrzeit für heute festlegen" : "Set time for today")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                            DatePicker("", selection: $pickedTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .colorScheme(.dark)
                            Button {
                                Task { await saveTime() }
                            } label: {
                                Text(K.L.de ? "Uhrzeit speichern" : "Save time")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(K.accentDark)
                                    .padding(.horizontal, 22).padding(.vertical, 10)
                                    .background(Color.white.cornerRadius(14))
                            }
                            .disabled(saving)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.14).cornerRadius(16))
                    }
                }

                Button {
                    hapticSuccess()
                    withAnimation(.easeIn(duration: 0.25)) { opacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
                } label: {
                    Text(K.L.de ? "Los geht's!" : "Let's go!")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(K.accentDark)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Color.white.cornerRadius(20))
                }
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }

    private func saveTime() async {
        guard let group = appState.activeGroup else { return }
        saving = true
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        try? await APIClient.shared.setCheckinTime(groupId: group.id,
                                                   date: dateYMD(Date()),
                                                   time: f.string(from: pickedTime))
        await appState.refreshData()
        saving = false
    }
}
