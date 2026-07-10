import SwiftUI

struct LandingView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var toast: String?

    var body: some View {
        ZStack {
            GymBackground()

            ScrollView {
                VStack(spacing: 32) {
                    // Hero
                    VStack(spacing: 12) {
                        Text("🏋️").font(.system(size: 64))
                        Text(K.L.appName)
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(
                                LinearGradient(colors: [K.accentDeep, K.accent],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text(K.L.tagline)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 60)

                    // Feature pills
                    HStack(spacing: 10) {
                        FeaturePill(icon: "flame.fill", label: K.L.lsFeatStreak)
                        FeaturePill(icon: "clock.fill", label: K.L.lsFeatCheckin)
                        FeaturePill(icon: "person.3.fill", label: K.L.lsFeatGroup)
                    }

                    // CTA buttons
                    VStack(spacing: 12) {
                        Button { showCreate = true } label: {
                            Label(K.L.create, systemImage: "plus.circle.fill")
                                .accentButton()
                        }
                        Button { showJoin = true } label: {
                            Label(K.L.join, systemImage: "link")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(K.accentDark)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .glassButton(radius: 16)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }
        }
        .fullPageCover(isPresented: $showCreate) { CreateGroupSheet() }
        .fullPageCover(isPresented: $showJoin) { JoinGroupSheet() }
        .toast($toast)
    }
}

struct FeaturePill: View {
    let icon: String; let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(K.accentDeep).font(.system(size: 12))
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .glassCard(radius: 20)
    }
}
