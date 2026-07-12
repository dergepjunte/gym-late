import SwiftUI

// MARK: - Animation helpers (web: w-pop, w-rise, w-fade)

struct WPop<Content: View>: View {
    let delay: Double
    @ViewBuilder let content: () -> Content
    @State private var appeared = false

    var body: some View {
        content()
            .scaleEffect(appeared ? 1 : 0.3)
            .rotationEffect(.degrees(appeared ? 0 : -6))
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(delay)) {
                    appeared = true
                }
            }
    }
}

struct WRise<Content: View>: View {
    let delay: Double
    @ViewBuilder let content: () -> Content
    @State private var appeared = false

    var body: some View {
        content()
            .offset(y: appeared ? 0 : 36)
            .blur(radius: appeared ? 0 : 6)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.interpolatingSpring(stiffness: 120, damping: 18).delay(delay)) {
                    appeared = true
                }
            }
    }
}

struct WFade<Content: View>: View {
    let delay: Double
    @ViewBuilder let content: () -> Content
    @State private var appeared = false

    var body: some View {
        content()
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                    appeared = true
                }
            }
    }
}

// Count-up number (web: wCount with ease-out cubic)
struct WCountUp: View {
    let target: Int
    let delay: Double
    @State private var value = 0

    var body: some View {
        Text("\(value)")
            .onAppear {
                Task {
                    if delay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                    let dur = min(1.4, 0.5 + Double(target) * 0.025)
                    let start = Date.now
                    while true {
                        let elapsed = max(0, Date.now.timeIntervalSince(start))
                        let p = min(elapsed / dur, 1.0)
                        let e = 1 - pow(1 - p, 3)          // ease-out cubic
                        await MainActor.run { value = Int(Double(target) * e) }
                        if p >= 1 { await MainActor.run { value = target }; break }
                        try? await Task.sleep(nanoseconds: 16_000_000)
                    }
                }
            }
    }
}

// MARK: - Text style helpers

extension Text {
    func wLabel() -> some View {
        self
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white.opacity(0.6))
            .tracking(1)
            .textCase(.uppercase)
    }

    func wNumber() -> some View {
        self
            .font(.system(size: 110, weight: .black).italic()
                .monospacedDigit())
            .foregroundColor(.white)
            .tracking(-5)
    }
}

extension View {
    func wNumber() -> some View {
        self
            .font(.system(size: 110, weight: .black).italic()
                .monospacedDigit())
            .foregroundColor(.white)
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
