import SwiftUI

/// Daily gym-day hype (website: #daily-hype) — incl. the fixed check-in time
/// section: whoever opens the app first sets today's time; afterwards the
/// time and the ±10-minute window are displayed.
struct DailyHypeView: View {
    let onDismiss: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var appeared = false
    @State private var pulse = false
    @State private var drift = false
    @State private var pickedTime: Date = {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 18; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()
    @State private var saving = false
    /// Gesendeter Vorschlag (wartet auf die Zustimmung der anderen) und Fehlertext.
    @State private var proposedTime: String?
    @State private var errorText: String?

    private var fixedTimeActive: Bool { appState.groupData?.fixedCheckinEnabled == true }
    private var todaysTime: String? {
        guard let d = appState.groupData, d.checkinTimeDate == dateYMD(Date()) else { return nil }
        return d.checkinTime
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#fbbf24"), Color(hex: "#f59e0b"), Color(hex: "#ea580c")],
                startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

            // Weiche, langsam wandernde Lichtflecken statt flacher Farbe.
            GeometryReader { geo in
                Circle().fill(Color.white.opacity(0.22)).frame(width: 340).blur(radius: 70)
                    .offset(x: drift ? -60 : 40, y: drift ? -40 : 60)
                Circle().fill(Color(hex: "#dc2626").opacity(0.35)).frame(width: 380).blur(radius: 90)
                    .position(x: geo.size.width * 0.9, y: geo.size.height * (drift ? 0.88 : 0.78))
                ForEach(0..<7, id: \.self) { i in
                    Image(systemName: "sparkle")
                        .font(.system(size: CGFloat(10 + (i * 5) % 14)))
                        .foregroundColor(.white.opacity(pulse ? 0.85 : 0.2))
                        .position(x: geo.size.width * [0.12, 0.84, 0.28, 0.7, 0.9, 0.08, 0.55][i],
                                  y: geo.size.height * [0.2, 0.16, 0.34, 0.62, 0.48, 0.7, 0.1][i])
                        .animation(.easeInOut(duration: 1.2 + Double(i) * 0.17).repeatForever(autoreverses: true), value: pulse)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 26) {
                Spacer(minLength: 20)

                ZStack {
                    Circle().stroke(Color.white.opacity(0.35), lineWidth: 2)
                        .frame(width: 190, height: 190)
                        .scaleEffect(pulse ? 1.18 : 0.92).opacity(pulse ? 0 : 0.8)
                    Circle().fill(.ultraThinMaterial).frame(width: 150, height: 150)
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1.5))
                        .shadow(color: Color(hex: "#7c2d12").opacity(0.35), radius: 24, y: 12)
                    Text("🏋️").font(.system(size: 76))
                }
                .scaleEffect(appeared ? 1 : 0.5).opacity(appeared ? 1 : 0)

                VStack(spacing: 10) {
                    Text(K.L.de ? "Heute ist Gym-Tag!" : "Today is Gym Day!")
                        .font(Theme.display(38))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .shadow(color: Color(hex: "#7c2d12").opacity(0.35), radius: 8, y: 3)
                    Text(K.L.de ? "Zeig, was du drauf hast. 💪" : "Show them what you've got. 💪")
                        .font(Theme.body(18, .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 24)
                .offset(y: appeared ? 0 : 24).opacity(appeared ? 1 : 0)

                // Fixed check-in time (beta): set or display today's time
                if fixedTimeActive {
                    Group {
                        if let time = todaysTime {
                            VStack(spacing: 4) {
                                Text(K.L.de ? "Heutige Uhrzeit" : "Today's time")
                                    .font(Theme.body(13, .semibold)).foregroundColor(.white.opacity(0.8))
                                Text(time)
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(.white)
                                Text(K.L.dhTimeWindowHint(time))
                                    .font(Theme.body(12)).foregroundColor(.white.opacity(0.8))
                            }
                        } else if let sent = proposedTime {
                            VStack(spacing: 8) {
                                Text(K.L.de ? "Vorschlag gesendet" : "Proposal sent")
                                    .font(Theme.body(13, .semibold)).foregroundColor(.white.opacity(0.9))
                                Text(sent)
                                    .font(.system(size: 36, weight: .black, design: .rounded)).monospacedDigit()
                                    .foregroundColor(.white)
                                Text(K.L.de ? "Fest wird die Zeit, sobald die anderen im Chat zustimmen."
                                            : "It becomes fixed once the others agree in the chat.")
                                    .font(Theme.body(12)).foregroundColor(.white.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                Button {
                                    hapticSuccess()
                                    appState.openChatRequest = true
                                    withAnimation(.easeIn(duration: 0.25)) { appeared = false }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
                                } label: {
                                    Text(K.L.de ? "Zum Chat" : "Open chat")
                                        .font(Theme.body(14, .bold)).foregroundColor(.white)
                                        .padding(.horizontal, 22).padding(.vertical, 10)
                                        .background(Capsule().fill(Color.white.opacity(0.22)))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            VStack(spacing: 10) {
                                Text(K.L.de ? "Gym-Zeit für heute vorschlagen" : "Propose today's gym time")
                                    .font(Theme.body(13, .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                                DatePicker("", selection: $pickedTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                Button {
                                    Task { await proposeTime() }
                                } label: {
                                    Text(saving ? (K.L.de ? "Sende …" : "Sending …") : (K.L.de ? "Zeit vorschlagen" : "Propose time"))
                                        .font(Theme.body(14, .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 22).padding(.vertical, 10)
                                        .background(Capsule().fill(Color.white.opacity(0.22)))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .disabled(saving)
                                Text(K.L.de ? "Die anderen stimmen im Chat ab." : "The others vote in the chat.")
                                    .font(Theme.body(12)).foregroundColor(.white.opacity(0.8))
                                if let errorText {
                                    Text(errorText).font(Theme.body(12, .semibold)).foregroundColor(.white)
                                        .padding(8).background(Capsule().fill(Color.red.opacity(0.55)))
                                }
                            }
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: 320)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.35), lineWidth: 1))
                    .opacity(appeared ? 1 : 0)
                }

                Spacer(minLength: 20)

                Button {
                    hapticSuccess()
                    withAnimation(.easeIn(duration: 0.25)) { appeared = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
                } label: {
                    Text(K.L.de ? "Los geht's!" : "Let's go!")
                        .font(Theme.heading(19))
                        .foregroundColor(K.accentDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule().fill(Color.white))
                        .shadow(color: Color(hex: "#7c2d12").opacity(0.3), radius: 16, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .offset(y: appeared ? 0 : 40).opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) { appeared = true }
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { drift = true }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
        }
    }

    private func proposeTime() async {
        guard let group = appState.activeGroup, let profile = appState.userProfile else { return }
        saving = true
        errorText = nil
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        let hhmm = f.string(from: pickedTime)
        do {
            _ = try await APIClient.shared.chatPropose(
                groupId: group.id,
                auth: ChatAuth(userId: profile.userId, recoveryCode: profile.recoveryCode,
                               accountToken: appState.account?.accountToken),
                date: dateYMD(Date()), time: hhmm)
            hapticSuccess()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { proposedTime = hhmm }
            await appState.refreshData()   // bei einer Person oder sofortiger Mehrheit steht die Zeit schon fest
        } catch {
            errorText = K.L.de ? "Konnte nicht gesendet werden. Bitte nochmal versuchen." : "Couldn't send. Please try again."
        }
        saving = false
    }
}
