import SwiftUI

extension WrappedView {
    // MARK: - Individual slides

    @ViewBuilder
    func introSlide(groupName: String, weekRange: String) -> some View {
        VStack(spacing: 0) {
            WFade(delay: 0) {
                Text(groupName.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.5)
                    .multilineTextAlignment(.center)
            }
            Spacer().frame(height: 14)
            WPop(delay: 0) {
                Text("🏋️").font(.system(size: 64))
            }
            Spacer().frame(height: 14)
            WRise(delay: 0.25) {
                Text(K.L.de ? "DIESE" : "THIS")
                    .font(.system(size: 72, weight: .black).italic())
                    .foregroundColor(.white)
                    .tracking(-3)
            }
            WRise(delay: 0.4) {
                Text(K.L.de ? "WOCHE" : "WEEK")
                    .font(.system(size: 72, weight: .black).italic())
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(-3)
            }
            Spacer().frame(height: 24)
            WFade(delay: 0.65) {
                Text(weekRange)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    func lateCountSlide(count: Int) -> some View {
        VStack(spacing: 0) {
            WFade(delay: 0) {
                Text((K.L.de ? "ihr wart" : "you were late").uppercased())
                    .wLabel()
            }
            Spacer().frame(height: 8)
            WPop(delay: 0.1) {
                WCountUp(target: count, delay: 0.28)
                    .wNumber()
            }
            Spacer().frame(height: 8)
            WRise(delay: 0.3) {
                Text(K.L.de ? "zu spät" : "times")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
                    .tracking(-0.5)
            }
            Spacer().frame(height: 24)
            WPop(delay: 0.5) {
                Text("🚨").font(.system(size: 58))
            }
        }
    }

    @ViewBuilder
    func skipsSlide(count: Int, topName: String, topCount: Int) -> some View {
        VStack(spacing: 0) {
            WFade(delay: 0) {
                Text((K.L.de ? "ihr habt gekniffen" : "you bailed").uppercased())
                    .wLabel()
            }
            Spacer().frame(height: 8)
            WPop(delay: 0.1) {
                WCountUp(target: count, delay: 0.28)
                    .wNumber()
            }
            Spacer().frame(height: 8)
            WRise(delay: 0.3) {
                Text(K.L.de ? "mal" : "times")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
                    .tracking(-0.5)
            }
            Spacer().frame(height: 24)
            WPop(delay: 0.5) {
                Text("⊘").font(.system(size: 58))
            }
            Spacer().frame(height: 14)
            WFade(delay: 0.65) {
                Text(K.L.de
                     ? "Größter Drückeberger: \(topName) (\(topCount)×)"
                     : "Biggest ghoster: \(topName) (\(topCount)×)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    @ViewBuilder
    func minutesSlide(total: Int) -> some View {
        let hours = total / 60, remMins = total % 60
        VStack(spacing: 0) {
            WFade(delay: 0) {
                Text((K.L.de ? "ihr habt verbraten" : "you wasted").uppercased())
                    .wLabel()
            }
            Spacer().frame(height: 8)
            WPop(delay: 0.1) {
                WCountUp(target: total, delay: 0.28)
                    .wNumber()
            }
            WRise(delay: 0.3) {
                Text(K.L.de ? "Minuten" : "minutes")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
                    .tracking(-0.5)
            }
            if hours > 0 {
                Spacer().frame(height: 14)
                WFade(delay: 0.55) {
                    Text(K.L.de
                         ? "das sind \(hours)h \(remMins)min"
                         : "that's \(hours)h \(remMins)min")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }

    @ViewBuilder
    func kingSlide(name: String, count: Int, mins: Int) -> some View {
        VStack(spacing: 0) {
            WPop(delay: 0) {
                Text("👑").font(.system(size: 64))
            }
            Spacer().frame(height: 14)
            WRise(delay: 0.2) {
                Text((K.L.de ? "Zuspätkommer der Woche" : "Latecomer of the Week").uppercased())
                    .wLabel()
                    .multilineTextAlignment(.center)
            }
            Spacer().frame(height: 14)
            WPop(delay: 0.38) {
                Text(name)
                    .font(.system(size: 52, weight: .black).italic())
                    .foregroundColor(.white)
                    .tracking(-2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)
            }
            Spacer().frame(height: 24)
            WFade(delay: 0.6) {
                Text("\(count)× · \(mins) \(K.L.minsShort)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    @ViewBuilder
    func rankingSlide(rows: [(name: String, count: Int, mins: Int)]) -> some View {
        VStack(spacing: 0) {
            WRise(delay: 0) {
                Text((K.L.de ? "Die Rangliste" : "The Ranking").uppercased())
                    .font(.system(size: 48, weight: .black).italic())
                    .foregroundColor(.white)
                    .tracking(-2)
                    .multilineTextAlignment(.center)
            }
            Spacer().frame(height: 14)
            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 44, height: 3)
                .clipShape(Capsule())
            Spacer().frame(height: 14)
            ForEach(Array(rows.prefix(5).enumerated()), id: \.offset) { i, row in
                WRise(delay: 0.2 + Double(i) * 0.13) {
                    HStack(spacing: 14) {
                        Text(["🥇","🥈","🥉"][safe: i] ?? "\(i+1).")
                            .font(.system(size: 22))
                            .frame(width: 28)
                        Text(row.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                        Text("\(row.mins) \(K.L.minsShort)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 11)
                    .overlay(alignment: .bottom) {
                        if i < min(rows.count, 5) - 1 {
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 360)
    }

    @ViewBuilder
    func ctaSlide() -> some View {
        VStack(spacing: 0) {
            WPop(delay: 0) {
                Text("💪").font(.system(size: 64))
            }
            Spacer().frame(height: 14)
            WRise(delay: 0.2) {
                Text(K.L.de ? "NÄCHSTE" : "DO BETTER")
                    .font(.system(size: 68, weight: .black).italic())
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(-3)
                    .multilineTextAlignment(.center)
            }
            WRise(delay: 0.36) {
                Text(K.L.de ? "WOCHE\nBESSER." : "NEXT WEEK.")
                    .font(.system(size: 68, weight: .black).italic())
                    .foregroundColor(.white)
                    .tracking(-3)
                    .multilineTextAlignment(.center)
            }
            Spacer().frame(height: 40)
            WPop(delay: 0.6) {
                Button {
                    hapticSuccess()
                    onDismiss()
                } label: {
                    Text(K.L.de ? "Los geht's" : "Let's go")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(Color(hex: "#1a0030"))
                        .padding(.horizontal, 52)
                        .padding(.vertical, 18)
                        .background(Color.white.clipShape(Capsule()))
                        .shadow(color: .black.opacity(0.4), radius: 28, y: 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
