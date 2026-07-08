import SwiftUI

struct GeoPromptView: View {
    let onCheckin: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("📍").font(.system(size: 64))

                VStack(spacing: 8) {
                    Text("Du bist im Gym!")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                    Text("Möchtest du einchecken?")
                        .foregroundColor(.white.opacity(0.8))
                }

                HStack(spacing: 16) {
                    Button {
                        withAnimation { appState.showGeoPrompt = false }
                    } label: {
                        Text("Später")
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
                        Text("Einchecken")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(K.accentDark)
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
