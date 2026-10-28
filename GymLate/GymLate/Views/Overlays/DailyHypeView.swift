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
            // Gym-poster stage: black floor, swinging spotlight, hazard tape top and bottom.
            GymBackground()
            GeometryReader { geo in
                RadialGradient(colors: [K.accent.opacity(0.32), .clear],
                               center: .init(x: drift ? 0.38 : 0.62, y: 0.28),
                               startRadius: 0, endRadius: geo.size.height * 0.45)
                VStack {
                    HazardStripes(stripe: 16).frame(height: 22)
                        .offset(x: drift ? -32 : 0)
                    Spacer()
                    HazardStripes(stripe: 16).frame(height: 22)
                        .offset(x: drift ? 0 : -32)
                }
                .frame(width: geo.size.width + 64)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 26) {
                Spacer(minLength: 20)

                ZStack {
                    Circle().stroke(K.accent.opacity(0.5), lineWidth: 3)
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulse ? 1.2 : 0.9).opacity(pulse ? 0 : 0.9)
                    PlateFrame(size: 170) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 58, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: Theme.accentGradient,
                                                            startPoint: .top, endPoint: .bottom))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(K.iron1)
                    }
                    .rotationEffect(.degrees(appeared ? 0 : -90))
                }
                .scaleEffect(appeared ? 1 : 0.5).opacity(appeared ? 1 : 0)

                VStack(spacing: 6) {
                    Text(K.L.de ? "GYM-TAG" : "GYM DAY")
                        .font(Theme.display(86))
                        .foregroundStyle(LinearGradient(colors: Theme.accentGradient,
                                                        startPoint: .top, endPoint: .bottom))
                        .shadow(color: K.accent.opacity(0.45), radius: 20)
                        .scaleEffect(appeared ? 1 : 1.6)
                    Text((K.L.de ? "Zeig, was du drauf hast." : "Show them what you've got.").uppercased())
                        .font(.system(size: 17, weight: .heavy).width(.condensed))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.85))
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
                                    .font(Theme.display(56))
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
                                    .font(Theme.display(56)).monospacedDigit()
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
                                        .font(.system(size: 15, weight: .black).width(.condensed))
                                        .textCase(.uppercase)
                                        .foregroundColor(K.onAccent)
                                        .padding(.horizontal, 22).padding(.vertical, 11)
                                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(K.accent))
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
                                        .font(.system(size: 15, weight: .black).width(.condensed))
                                        .textCase(.uppercase)
                                        .tracking(1)
                                        .foregroundColor(K.accent)
                                        .padding(.horizontal, 22).padding(.vertical, 11)
                                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(K.accent.opacity(0.12)))
                                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(K.accent, lineWidth: 1.5))
                                }
                                .buttonStyle(SlabPress())
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
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(K.iron2))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(K.accent.opacity(0.35), lineWidth: 1))
                    .opacity(appeared ? 1 : 0)
                }

                Spacer(minLength: 20)

                Button {
                    hapticSuccess()
                    withAnimation(.easeIn(duration: 0.25)) { appeared = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
                } label: {
                    Text(K.L.de ? "Los geht's!" : "Let's go!")
                        .accentButton()
                }
                .buttonStyle(SlabPress())
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
