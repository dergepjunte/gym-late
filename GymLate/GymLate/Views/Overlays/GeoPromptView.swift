import SwiftUI

/// Geo check-in prompt (website: #geo-prompt) — offers a normal check-in on
/// gym days and a "log anyway" variant on rest days. Glass-Karte von unten mit
/// einem Radar-Ping um die Standortnadel.
struct GeoPromptView: View {
    let onCheckin: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var appeared = false
    @State private var ping = false

    private var todayIsGymDay: Bool {
        dayScheduled(dateYMD(Date()), mask: appState.groupData?.gymDays ?? "0000000")
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(appeared ? 0.55 : 0).ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(K.accentDeep.opacity(0.5), lineWidth: 2)
                            .frame(width: 84, height: 84)
                            .scaleEffect(ping ? 2.1 : 0.9)
                            .opacity(ping ? 0 : 0.7)
                            .animation(.easeOut(duration: 2).repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.65), value: ping)
                    }
                    Circle()
                        .fill(LinearGradient(colors: Theme.accentGradient,
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 84, height: 84)
                        .shadow(color: K.accentDeep.opacity(0.45), radius: 18, y: 8)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(K.onAccent)
                }
                .frame(height: 120)

                VStack(spacing: 8) {
                    Text(todayIsGymDay
                         ? (K.L.de ? "Du bist im Gym!" : "You're at the gym!")
                         : (K.L.de ? "Kein Gym-Tag heute" : "Not a gym day today"))
                        .font(Theme.display(28))
                        .multilineTextAlignment(.center)
                    Text(todayIsGymDay
                         ? (K.L.de ? "Möchtest du einchecken?" : "Want to check in?")
                         : (K.L.de ? "Heute steht kein Training auf dem Plan." : "There's no training scheduled today."))
                        .font(Theme.body(16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Button {
                        onCheckin()
                        hapticSuccess()
                        close()
                    } label: {
                        Text(todayIsGymDay
                             ? (K.L.de ? "Einchecken" : "Check in")
                             : (K.L.de ? "Trotzdem einchecken" : "Log check-in anyway"))
                            .font(Theme.heading(17))
                            .foregroundColor(K.onAccent)
                            .lineLimit(1).minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(LinearGradient(colors: Theme.accentGradient,
                                                                      startPoint: .topLeading, endPoint: .bottomTrailing)))
                    }
                    .buttonStyle(.plain)

                    Button { close() } label: {
                        Text(K.L.de ? "Später" : "Later")
                            .font(Theme.body(15, .semibold))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 28)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.25), radius: 30, y: -6)
                    .ignoresSafeArea(edges: .bottom)
            )
            .offset(y: appeared ? 0 : 420)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) { appeared = true }
            if !UIAccessibility.isReduceMotionEnabled { ping = true }
        }
    }

    private func close() {
        withAnimation(.easeIn(duration: 0.22)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            appState.showGeoPrompt = false
        }
    }
}
