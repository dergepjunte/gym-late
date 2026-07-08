import SwiftUI

struct DailyHypeView: View {
    let onDismiss: () -> Void
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: Theme.hype,
                startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Text("🏋️")
                    .font(.system(size: 100))
                    .scaleEffect(scale)

                VStack(spacing: 12) {
                    Text("Heute ist Gym-Tag!")
                        .font(.system(size: 34, weight: .black))
                        .foregroundColor(.white)
                    Text("Zeig, was du drauf hast. 💪")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }

                Button {
                    hapticSuccess()
                    withAnimation(.easeIn(duration: 0.25)) { opacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
                } label: {
                    Text("Los geht's!")
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
}
