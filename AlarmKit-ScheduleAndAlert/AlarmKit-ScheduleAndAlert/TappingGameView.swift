import SwiftUI
import Foundation

// Local hex color helper (keeps this file self-contained).
private extension Color {
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }

        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

struct TapParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0
    var symbol: String
}

struct TappingGameView: View {
    var onComplete: () -> Void

    @State private var targetTaps: Int = Int.random(in: 30...60)
    @State private var tapCount: Int = 0
    @State private var particles: [TapParticle] = []
    @State private var isAwake: Bool = false
    @State private var screenShake: CGFloat = 0
    @State private var hasTriggeredWakeUp = false

    @State private var isShowingJumpScare = false
    @State private var lastJumpScareAt = Date.distantPast

    // Show exactly once at mid progress.
    @State private var hasShownMidJumpScare = false

    // MARK: - LOCAL DIALOG STATE (no FoundationModels)
    @State private var dynamicLabel: String = "Zzz..."

    /// Keep it short (1-3 words), like the AI prompt used to.
    private let clockieMoods = ["grumpy", "sarcastic", "sleepy", "confused", "dizzy", "dramatic", "poetic", "angry"]

    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let symbols = ["💥", "⭐", "✨", "💢", "❗"]

    // Hitung progress 0.0 sampai 1.0
    private var progress: Double {
        min(Double(tapCount) / Double(targetTaps), 1.0)
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 20) {
                title

                Spacer()

                ZStack {
                    // MENGGUNAKAN CLOCKIE SEBAGAI TARGET TAP
                    // Pastikan struct ClockieTapTarget sudah ada di project kamu
                    ClockieTapTarget(progress: progress, isAwake: isAwake)
                        .frame(width: 250, height: 250)
                        .offset(x: screenShake)

                    // Area Hitbox
                    Color.clear
                        .frame(width: 320, height: 320)
                        .contentShape(Rectangle())
                        .offset(x: screenShake)
                        .allowsHitTesting(!isShowingJumpScare)
                        .onTapGesture(coordinateSpace: .global) { location in
                            handleTap(at: location)
                        }
                }

                statusText
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)

            ForEach(particles) { particle in
                Text(particle.symbol)
                    .font(.system(size: 28))
                    .position(particle.position)
                    .opacity(particle.opacity)
                    .scaleEffect(particle.scale)
                    .allowsHitTesting(false)
            }

            if isShowingJumpScare {
                JumpScareOverlayView(isPresented: $isShowingJumpScare)
                    .transition(.opacity)
                    .zIndex(1000)
            }
        }
        .onAppear {
            haptic.prepare()
        }
    }

    // Gradient sesuai tema Clockie
    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.95, blue: 0.88),
                Color(red: 1.0, green: 0.88, blue: 0.70),
                Color(red: 1.0, green: 0.80, blue: 0.50)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var title: some View {
        VStack(spacing: 4) {
            Text("Wakey Wakey!")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundColor(Color(red: 0.6, green: 0.2, blue: 0.0))
            
            Text("Tap the clock to wake him up!")
                .font(.subheadline)
                .foregroundColor(.orange)
        }
        .padding(.top, 20)
    }

    private var statusText: some View {
        Group {
            if !isAwake {
                Text(dynamicLabel)
                    .foregroundColor(Color(red: 0.6, green: 0.2, blue: 0.0))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .italic(progress > 0.7) // Efek miring kalau hampir bangun (pusing)
                    .animation(.spring(), value: dynamicLabel)
            } else {
                Text("FINALLY AWAKE! 🎉")
                    .foregroundColor(.green)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .multilineTextAlignment(.center)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.8))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.orange, lineWidth: 3))
        .padding(.horizontal, 40)
    }

    private func handleTap(at location: CGPoint) {
        guard !isAwake else { return }
        guard !isShowingJumpScare else { return }

        tapCount += 1
        haptic.impactOccurred()
        spawnParticle(at: location)
        shakeScreen()

        maybeTriggerJumpScare()

        if tapCount >= targetTaps {
            triggerWakeUp()
        } else {
            generateLocalResponse()
        }
    }

    // MARK: - LOCAL DIALOG GENERATOR (in-code)
    private func generateLocalResponse() {
        let mood = clockieMoods.randomElement() ?? "sleepy"
        let percent = Int(progress * 100)

        // Bucket progress to keep responses feeling like they're evolving.
        let stage: Int
        switch progress {
        case ..<0.25: stage = 0
        case ..<0.5: stage = 1
        case ..<0.75: stage = 2
        case ..<0.95: stage = 3
        default: stage = 4
        }

        let line = localLine(mood: mood, stage: stage, percent: percent)
        withAnimation(.snappy) {
            dynamicLabel = line
        }
    }

    private func localLine(mood: String, stage: Int, percent: Int) -> String {
        // Goal: 1-3 words, uppercase-ish vibe like before.
        func pick(_ items: [String]) -> String { items.randomElement() ?? "..." }

        switch (mood, stage) {
        case ("sleepy", 0): return pick(["NOPE", "5 MORE", "SNOOZE", "MMPH"])
        case ("sleepy", 1): return pick(["TOO BRIGHT", "WHY", "NO TOUCH", "YAWN"])
        case ("sleepy", 2): return pick(["I SAW THAT", "STILL NO", "HALF ALIVE", "GRAH"])
        case ("sleepy", 3): return pick(["OKAY OKAY", "ALMOST", "STOP POKING", "AAA"])
        case ("sleepy", _): return pick(["I'M UP", "FINE", "DONE", "AAAA"])

        case ("grumpy", 0): return pick(["RUDE", "QUIT", "HANDS OFF", "NO"])
        case ("grumpy", 1): return pick(["SERIOUSLY", "STOP", "I BITE", "UGH"])
        case ("grumpy", 2): return pick(["YOU AGAIN", "GO AWAY", "ABSOLUTELY NOT", "HMPH"])
        case ("grumpy", 3): return pick(["LAST WARNING", "I'M WATCHING", "ENOUGH", "GRR"])
        case ("grumpy", _): return pick(["FINE", "HAPPY?", "YOU WIN", "SIGH"])

        case ("sarcastic", 0): return pick(["AMAZING", "SO ORIGINAL", "WOW", "CLAP"])
        case ("sarcastic", 1): return pick(["GENTLE", "SUCH CARE", "INSPIRING", "BRAVO"])
        case ("sarcastic", 2): return pick(["10/10", "OSCAR", "AGAIN?", "ICONIC"])
        case ("sarcastic", 3): return pick(["NEARLY", "KEEP DRAMATIZING", "YEAH YEAH", "EVENTUALLY"])
        case ("sarcastic", _): return pick(["CONGRATS", "I'M AWAKE", "HERO", "BIG WIN"])

        case ("confused", 0): return pick(["WHO ARE YOU", "WHAT", "HUH", "ERROR"])
        case ("confused", 1): return pick(["WHY ME", "WHERE AM I", "BUFFERING", "??"])
        case ("confused", 2): return pick(["IS THIS REAL", "PARDON", "WAIT", "MATH"])
        case ("confused", 3): return pick(["OH", "OH NO", "I GET IT", "ALMOST"])
        case ("confused", _): return pick(["OK", "I'M BACK", "AHA", "DONE"])

        case ("dizzy", 0): return pick(["SPINNY", "WOAH", "BLUR", "EEEK"])
        case ("dizzy", 1): return pick(["DIZZY", "WOBBLE", "WHOOSH", "TILT"])
        case ("dizzy", 2): return pick(["MY GEARS", "N O", "WHEEEE", "HELP"])
        case ("dizzy", 3): return pick(["I'M VIBRATING", "STARS", "ALMOST", "STOP"])
        case ("dizzy", _): return pick(["RECOVERING", "OKAY", "FOCUS", "UP"])

        case ("dramatic", 0): return pick(["TRAGEDY", "BETRAYAL", "CRUEL", "DESPAIR"])
        case ("dramatic", 1): return pick(["THE AUDACITY", "SCANDAL", "OH LAWD", "SIGH"])
        case ("dramatic", 2): return pick(["I PERISH", "FAREWELL", "THE PAIN", "WHY"])
        case ("dramatic", 3): return pick(["THE FINALE", "CURTAIN", "ALMOST", "ENOUGH"])
        case ("dramatic", _): return pick(["ENCORE", "I RISE", "FINALE", "AWAKE"])

        case ("poetic", 0): return pick(["SOFT DAWN", "TICK DREAM", "HUSH", "MORNING"])
        case ("poetic", 1): return pick(["SUN WHISPER", "GOLD LIGHT", "DRIFT", "WARM"])
        case ("poetic", 2): return pick(["BRIGHTER NOW", "CLOCK SOUL", "STIR", "NEAR"])
        case ("poetic", 3): return pick(["I RETURN", "ALMOST", "AWAKEN", "RISE"])
        case ("poetic", _): return pick(["I WAKE", "HELLO DAY", "I'M HERE", "DAWN"])

        case ("angry", 0): return pick(["NO", "STOP", "HEY", "GRRR"])
        case ("angry", 1): return pick(["HARDER?!", "DON'T", "ANGER", "AAAA"])
        case ("angry", 2): return pick(["I'M MAD", "UNHAND", "CHAOS", "RAGE"])
        case ("angry", 3): return pick(["ENOUGH", "ALMOST", "I SWEAR", "FINAL"])
        case ("angry", _): return pick(["OKAY!", "I'M UP!", "DONE!", "FINISH!"])

        default:
            // Fallback with some variety, keep it short.
            let pool = [
                "MORE", "FASTER", "ALMOST", "NOT YET", "WHY", "SERIOUSLY", "OKAY", "DONE", "WAKE MODE"
            ]
            
            if percent > 0 && percent < 100, Bool.random() {
                return "\(percent)%"
            }
            return pick(pool)
        }
    }

    private func maybeTriggerJumpScare() {
        guard !hasShownMidJumpScare else { return }
        let halfway = max(1, targetTaps / 2)
        guard tapCount >= halfway else { return }
        guard Date().timeIntervalSince(lastJumpScareAt) > 1 else { return }

        hasShownMidJumpScare = true
        lastJumpScareAt = Date()
        withAnimation(.easeInOut(duration: 0.12)) {
            isShowingJumpScare = true
        }
    }

    private func triggerWakeUp() {
        guard !hasTriggeredWakeUp else { return }
        hasTriggeredWakeUp = true
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
            isAwake = true
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            onComplete()
        }
    }

    private func shakeScreen() {
        let intensity = CGFloat.random(in: 6...14)
        withAnimation(.interpolatingSpring(stiffness: 400, damping: 6)) {
            screenShake = Bool.random() ? intensity : -intensity
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.interpolatingSpring(stiffness: 400, damping: 8)) {
                screenShake = 0
            }
        }
    }

    private func spawnParticle(at location: CGPoint) {
        guard let symbol = symbols.randomElement() else { return }

        let p = TapParticle(
            position: CGPoint(
                x: location.x + CGFloat.random(in: -30...30),
                y: location.y + CGFloat.random(in: -40...10)
            ),
            symbol: symbol
        )
        particles.append(p)

        let id = p.id
        withAnimation(.easeOut(duration: 0.6)) {
            if let idx = particles.firstIndex(where: { $0.id == id }) {
                particles[idx].opacity = 0
                particles[idx].scale = 1.8
                particles[idx].position.y -= 60
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            particles.removeAll { $0.id == id }
        }
    }
}

// MARK: - Dynamic Face Parts
struct DynamicEye: View {
    var state: Int
    var darkColor: Color
    
    var body: some View {
        Group {
            if state == 0 { // Tidur pulas (Garis Lengkung)
                SleepyEyeShape()
                    .stroke(darkColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 22, height: 10)
            } else if state == 1 { // Setengah melek (Kelopak turun)
                Circle()
                    .stroke(darkColor, lineWidth: 3)
                    .background(Circle().fill(Color.white))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle().fill(darkColor).frame(width: 8, height: 8).offset(y: 4)
                    )
                    .overlay(
                        Rectangle().fill(Color.white).frame(width: 24, height: 12).offset(y: -10)
                    )
                    .overlay(
                        Rectangle().fill(darkColor).frame(width: 24, height: 3).offset(y: -4)
                    )
            } else if state == 2 { // Pusing (Mata X)
                Text("X")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(darkColor)
            } else if state == 3 { // Hampir bangun (Mata kecil/Kaget)
                Circle()
                    .stroke(darkColor, lineWidth: 3)
                    .background(Circle().fill(Color.white))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle().fill(darkColor).frame(width: 4, height: 4)
                    )
            } else { // Bangun! (Mata besar)
                Circle()
                    .fill(darkColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle().fill(Color.white).frame(width: 8, height: 8).offset(x: 3, y: -4)
                    )
            }
        }
        .frame(width: 24, height: 24)
    }
}

struct SleepyEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: rect.height),
                          control: CGPoint(x: rect.width/2, y: -rect.height/2))
        return path
    }
}

struct DynamicMouth: View {
    var state: Int
    var darkColor: Color
    
    var body: some View {
        Group {
            if state == 0 { // Tidur (Zzz)
                Text("z")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.blue.opacity(0.5))
                    .offset(x: 20, y: -20)
            } else if state == 1 || state == 2 { // Terganggu (Garis Lurus)
                Capsule()
                    .fill(darkColor)
                    .frame(width: 20, height: 4)
            } else if state == 3 { // Menganga kecil
                Circle()
                    .fill(darkColor)
                    .frame(width: 14, height: 14)
            } else { // Teriak! (Segitiga terbuka)
                TriangleMouth()
                    .fill(Color.red)
                    .overlay(TriangleMouth().stroke(darkColor, style: StrokeStyle(lineWidth: 3, lineJoin: .round)))
                    .frame(width: 24, height: 20)
            }
        }
        .frame(height: 18)
    }
}

struct TriangleMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width/2, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// Dummy JumpScare Overlay for completeness (di-uncomment supaya tidak error saat build jika kamu belum punya struct-nya)
//struct JumpScareOverlayView: View {
//    @Binding var isPresented: Bool
//
//    var body: some View {
//        Color.black.ignoresSafeArea()
//            .overlay(
//                Text("BOO!")
//                    .font(.system(size: 80, weight: .black))
//                    .foregroundColor(.red)
//            )
//            .onAppear {
//                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
//                    isPresented = false
//                }
//            }
//    }
//}

#Preview {
    TappingGameView(onComplete: {})
}
