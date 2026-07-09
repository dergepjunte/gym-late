import SwiftUI

// Check-in ceremony overlays — website parity for #late-anim, #streak-anim
// and #modal-chest. All fullscreen, dismissed by their primary button; the
// caller chains the next step (AppState.afterLateAnim / afterStreakAnim).

// MARK: - Late check-in animation (website: #late-anim)

struct LateAnimView: View {
    let minsOff: Int
    let onClose: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(K.red.opacity(0.35))
                        .frame(width: 130, height: 130)
                        .blur(radius: 30)
                    Text("⏰")
                        .font(.system(size: 76))
                        .rotationEffect(.degrees(appeared ? 0 : -14))
                        .scaleEffect(appeared ? 1 : 0.6)
                }
                Text(K.L.laTitle)
                    .font(Theme.display(34))
                    .foregroundColor(.white)
                Text(K.L.laSub(minsOff))
                    .font(Theme.body(16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                Button { onClose() } label: {
                    Text(K.L.saContinue).accentButton()
                }
                .padding(.horizontal, 60)
                .padding(.top, 12)
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { appeared = true }
        }
    }
}

// MARK: - Streak extended animation (website: #streak-anim, Duolingo-style)

struct StreakAnimView: View {
    let newStreak: Int
    let onClose: () -> Void
    @State private var lit = false
    @State private var shownNumber: Int

    init(newStreak: Int, onClose: @escaping () -> Void) {
        self.newStreak = newStreak
        self.onClose = onClose
        _shownNumber = State(initialValue: max(0, newStreak - 1))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#fb923c").opacity(lit ? 0.45 : 0))
                        .frame(width: 170, height: 170)
                        .blur(radius: 40)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 110))
                        .foregroundStyle(
                            lit
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color(hex: "#fde047"), Color(hex: "#fb923c"), Color(hex: "#dc2626")],
                                startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Color.white.opacity(0.22)))
                        .scaleEffect(lit ? 1 : 0.82)
                }
                Text("\(shownNumber)")
                    .font(Theme.display(84))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                Text(K.L.saLbl(newStreak))
                    .font(Theme.body(20, .bold))
                    .foregroundColor(.white.opacity(0.8))
                Button { onClose() } label: {
                    Text(K.L.saContinue).accentButton()
                }
                .padding(.horizontal, 60)
                .padding(.top, 22)
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.35)) { lit = true }
            // Count up as the flame ignites (website: wCount after 750ms)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                withAnimation(.spring(response: 0.5)) { shownNumber = newStreak }
                hapticSuccess()
            }
        }
    }
}

// MARK: - Chest reveal (website: #modal-chest)

struct ChestView: View {
    let chest: ChestResult
    let onClose: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { onClose() }
            VStack(spacing: 12) {
                Text(chest.got_freeze ? "❄️" : "🎁")
                    .font(.system(size: 64))
                    .scaleEffect(appeared ? 1 : 0.4)
                    .rotationEffect(.degrees(appeared ? 0 : -12))
                Text(chest.got_freeze ? K.L.chestGotFreeze : K.L.chestNoReward)
                    .font(Theme.heading(20))
                Text(chest.got_freeze ? K.L.chestStreak(chest.streak) : K.L.chestStreak(chest.streak))
                    .font(Theme.body(14))
                    .foregroundColor(.secondary)
                Button { onClose() } label: {
                    Text(K.L.chestOk).accentButton()
                }
                .padding(.top, 10)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .glassCard(radius: 26)
            .padding(32)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { appeared = true }
        }
    }
}
