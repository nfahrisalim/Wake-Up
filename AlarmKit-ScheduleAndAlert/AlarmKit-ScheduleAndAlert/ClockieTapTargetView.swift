import SwiftUI

/// Clock target used in tapping game.
/// - Shows yellow bells like the main UI
/// - Keeps the dynamic facial expressions (sleepy/annoyed/dizzy/shocked)
struct ClockieTapTarget: View {
    var progress: Double
    var isAwake: Bool

    private let size: CGFloat = 220
    private let darkColor = Color(red: 0.17, green: 0.24, blue: 0.31) // #2C3E50
    private let orangeColor = Color(red: 0.9, green: 0.49, blue: 0.13) // #E67E22

    // Expression state based on progress.
    private var clockieState: Int {
        if isAwake { return 4 }
        if progress < 0.25 { return 0 }
        if progress < 0.5 { return 1 }
        if progress < 0.75 { return 2 }
        return 3
    }

    var body: some View {
        ZStack {
            // Bells (yellow circles). Keep them visible by reserving space.
            ClockieBellsView()
                .offset(y: -8)
                .rotationEffect(.degrees(clockieState > 1 ? Double.random(in: -5...5) : 0))
                .animation(.default, value: clockieState)
                .zIndex(1)

            ZStack {
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(orangeColor, lineWidth: 8))
                    .frame(width: size, height: size)

                // Numbers
                ForEach(1...12, id: \.self) { num in
                    let angle = Double(num) * 30.0 * .pi / 180.0
                    let radius = size/2 - 35
                    Text("\(num)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(orangeColor)
                        .position(x: size/2 + CGFloat(sin(angle)) * radius,
                                  y: size/2 - CGFloat(cos(angle)) * radius)
                }
                .frame(width: size, height: size)

                // Dynamic face
                VStack(spacing: 12) {
                    HStack(spacing: 28) {
                        DynamicEye(state: clockieState, darkColor: darkColor)
                        DynamicEye(state: clockieState, darkColor: darkColor)
                    }

                    DynamicMouth(state: clockieState, darkColor: darkColor)
                        .frame(width: 45, height: 18)
                }
                .offset(y: -5)

                // Hands
                Group {
                    Capsule()
                        .fill(orangeColor)
                        .frame(width: 8, height: size * 0.15)
                        .offset(y: -size * 0.075)
                        .rotationEffect(.degrees(isAwake ? 0 : (progress * 720)))

                    Capsule()
                        .fill(orangeColor)
                        .frame(width: 5, height: size * 0.25)
                        .offset(y: -size * 0.125)
                        .rotationEffect(.degrees(isAwake ? 90 : (progress * 1440)))
                }
                .animation(.spring(), value: progress)

                Circle()
                    .stroke(orangeColor, lineWidth: 4)
                    .background(Circle().fill(Color.white))
                    .frame(width: 14, height: 14)
            }
            .zIndex(2)
        }
        .padding(.top, 24)
    }
}

/// Bells used by tapping game. (Dedicated name to avoid clashing with ContentView's BellsView.)
struct ClockieBellsView: View {
    private let darkColor = Color(red: 0.17, green: 0.24, blue: 0.31) // #2C3E50
    private let yellowColor = Color(red: 1.0, green: 0.84, blue: 0.0)  // #FFD700

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.orange.opacity(0.55))
                .frame(width: 180, height: 4)
                .offset(y: -5)

            HStack(spacing: 70) {
                Circle()
                    .fill(yellowColor)
                    .overlay(Circle().stroke(darkColor, lineWidth: 4))
                    .frame(width: 40, height: 40)

                Circle()
                    .fill(yellowColor)
                    .overlay(Circle().stroke(darkColor, lineWidth: 4))
                    .frame(width: 40, height: 40)
            }

            VStack(spacing: 0) {
                Circle().fill(darkColor).frame(width: 14, height: 14)
                Rectangle().fill(darkColor).frame(width: 5, height: 20)
            }
            .offset(y: -15)
        }
    }
}
