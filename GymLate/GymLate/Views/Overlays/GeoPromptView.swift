import SwiftUI

/// Geo check-in prompt (website: #geo-prompt) — offers a normal check-in on
/// gym days and a "log anyway" variant on rest days.
struct GeoPromptView: View {
    let onCheckin: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var opacity: Double = 0

    private var todayIsGymDay: Bool {
        dayScheduled(dateYMD(Date()), mask: appState.groupData?.gymDays ?? "0000000")
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("📍").font(.system(size: 64))

                VStack(spacing: 8) {
                    Text(todayIsGymDay
                         ? (K.L.de ? "Du bist im Gym!" : "You're at the gym!")
                         : (K.L.de ? "Kein Gym-Tag heute" : "Not a gym day today"))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                    Text(todayIsGymDay
                         ? (K.L.de ? "Möchtest du einchecken?" : "Want to check in?")
                         : (K.L.de ? "Heute steht kein Training auf dem Plan." : "There's no training scheduled today."))
                        .foregroundColor(.white.opacity(0.8))
                }

                HStack(spacing: 16) {
                    Button {
                        withAnimation { appState.showGeoPrompt = false }
                    } label: {
                        Text(K.L.de ? "Später" : "Later")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.2).cornerRadius(16))
                    }

                    Button {
                        onCheckin()
                        hapticSuccess()
                        withAnimation { appState.showGeoPrompt = false }
                    } label: {
                        Text(todayIsGymDay
                             ? (K.L.de ? "Einchecken" : "Check in")
                             : (K.L.de ? "Trotzdem einchecken" : "Log check-in anyway"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(K.accentDark)
                            .lineLimit(1).minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.cornerRadius(16))
                    }
                }
            }
            .padding(32)
            .glassCard(radius: 28)
            .padding(.horizontal, 24)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4)) { opacity = 1 }
        }
    }
}
