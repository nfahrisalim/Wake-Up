import AlarmKit
import SwiftUI

// MARK: - Card styling helpers
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

// MARK: - Main View
struct ContentView: View {
    @State private var viewModel = ViewModel()
    @State private var selectedTime = Date.now
    
    @State private var isWiggling: Bool = false
    @State private var justAdded: Bool = false
    @State private var showDatePicker: Bool = false
    
    // State untuk menyimpan hari yang dipilih (misal: "Mon", "Tue")
    @State private var selectedDays: Set<String> = ["Mon", "Tue", "Wed", "Thu", "Fri"]

    @AppStorage(AlarmStopCoordinator.StopGamePreference.storageKey)
    private var stopGamePreferenceRawValue: String = AlarmStopCoordinator.StopGamePreference.random.rawValue

    private var stopGamePreference: AlarmStopCoordinator.StopGamePreference {
        get { AlarmStopCoordinator.StopGamePreference(rawValue: stopGamePreferenceRawValue) ?? .random }
        nonmutating set { stopGamePreferenceRawValue = newValue.rawValue }
    }
    
    let bgGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.95, blue: 0.88),
            Color(red: 1.0, green: 0.88, blue: 0.70),
            Color(red: 1.0, green: 0.80, blue: 0.50)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        NavigationStack {
            ZStack {
                bgGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerView
                            .padding(.top, 16)
                        
                        quickSetCard
                            .padding(.horizontal, 16)
                        
                        content
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .environment(viewModel)
        .onAppear { viewModel.fetchAlarms() }
        .tint(.orange)
    }
    
    private var headerView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                //Image(systemName: "bell.fill").foregroundColor(.orange).font(.title)
                Text("Wakey Wakey!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.6, green: 0.2, blue: 0.0))
                //Image(systemName: "bell.fill").foregroundColor(.orange).font(.title)
            }
            .rotationEffect(.degrees(isWiggling ? 2 : -2))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.15).repeatForever(autoreverses: true)) {
                    isWiggling.toggle()
                }
            }

            //Text("The alarm that won't let you snooze")
            //    .font(.subheadline)
            //    .foregroundColor(Color(hex: "#FFB86A") ?? .orange)
        }
    }

    private var quickSetCard: some View {
        VStack(spacing: 24) {
            

            ClockieHoldingDigitalClock(date: $selectedTime)
            

            SectionDivider(title: "REPEAT DAYS")
            RepeatDaysPicker(selectedDays: $selectedDays)
            

            SectionDivider(title: "WAKE-UP CHALLENGE")
            HStack(spacing: 12) {
                ChallengeCard(
                    title: "Push-Up!",
                    subtitle: "No pain",
                    icon: "dumbbell.fill",
                    isSelected: stopGamePreference == .pushUps,
                    action: { stopGamePreference = .pushUps }
                )
                
                ChallengeCard(
                    title: "Tap Frenzy!",
                    subtitle: "Tap crazy",
                    icon: "hand.tap.fill",
                    isSelected: stopGamePreference == .tapping,
                    action: { stopGamePreference = .tapping }
                )
                
                ChallengeCard(
                    title: "Random!",
                    subtitle: "Feel lucky?",
                    icon: "dice.fill",
                    isSelected: stopGamePreference == .random,
                    action: { stopGamePreference = .random }
                )
            }

            // SET ALARM BUTTON
            Button(action: scheduleQuickAlarm) {
                HStack {
                    Image(systemName: "plus")
                        .rotationEffect(.degrees(justAdded ? 360 : 0))
                    Text("Set This Alarm!")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: .orange.opacity(0.5), radius: 5, y: 3)
            }
            .buttonStyle(BouncyButtonStyle())
        }
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 22))
                    .symbolEffect(.wiggle, options: .repeating)
                    .foregroundColor(Color(red: 0.6, green: 0.2, blue: 0.0))
                
                Text("Your Alarms")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.6, green: 0.2, blue: 0.0))
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            if viewModel.hasUpcomingAlerts {
                alarmList(alarms: Array(viewModel.alarmsMap.values))
            } else {
                ContentUnavailableView(
                    "No Alarms",
                    systemImage: "moon.zzz.fill",
                    description: Text("You're safe... for now.")
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
        }
    }

    private func scheduleQuickAlarm() {
        withAnimation(.easeInOut(duration: 0.6)) { justAdded = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { justAdded = false }

        var form = AlarmForm()
        form.label = "Ring Up"
        form.scheduleEnabled = true
        form.selectedDate = selectedTime
        form.selectedSecondaryButton = .none

        // Map UI day IDs ("Mon", "Tue", ...) to AlarmKit Locale.Weekday for weekly repeats.
        let weekdayMap: [String: Locale.Weekday] = [
            "Mon": .monday,
            "Tue": .tuesday,
            "Wed": .wednesday,
            "Thu": .thursday,
            "Fri": .friday,
            "Sat": .saturday,
            "Sun": .sunday
        ]
        form.selectedDays = Set(selectedDays.compactMap { weekdayMap[$0] })

        viewModel.scheduleAlarm(with: form)
        viewModel.fetchAlarms()
    }

    private func alarmList(alarms: [ViewModel.AlarmsMap.Value]) -> some View {
        List {
            ForEach(alarms, id: \.0.id) { (alarm, label) in
                AlarmCell(alarm: alarm, label: label)
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onDelete { indexSet in
                indexSet.forEach { idx in
                    viewModel.unscheduleAlarm(with: alarms[idx].0.id)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .frame(height: CGFloat(alarms.count * 100))
    }
}

// MARK: - Repeat Days Component

struct DayConfig {
    let id: String
    let icon: String
    let bgColor: Color
    let borderColor: Color
    let contentColor: Color
}

struct RepeatDaysPicker: View {
    @Binding var selectedDays: Set<String>
    
    let daysData: [DayConfig] = [
        DayConfig(id: "Mon", icon: "cup.and.saucer.fill", bgColor: Color(hex: "#FFF7D4")!, borderColor: Color(hex: "#F9C31C")!, contentColor: Color(hex: "#935F1D")!),
        DayConfig(id: "Tue", icon: "bolt.fill", bgColor: Color(hex: "#FEF9CD")!, borderColor: Color(hex: "#EAD610")!, contentColor: Color(hex: "#87661A")!),
        DayConfig(id: "Wed", icon: "flame.fill", bgColor: Color(hex: "#FCEBDF")!, borderColor: Color(hex: "#F39E36")!, contentColor: Color(hex: "#A9481E")!),
        DayConfig(id: "Thu", icon: "cloud.rain.fill", bgColor: Color(hex: "#EBF5FF")!, borderColor: Color(hex: "#4EAFFD")!, contentColor: Color(hex: "#235D96")!),
        DayConfig(id: "Fri", icon: "star.fill", bgColor: Color(hex: "#FBEAF4")!, borderColor: Color(hex: "#F07EC7")!, contentColor: Color(hex: "#A11F68")!),
        DayConfig(id: "Sat", icon: "moon.stars.fill", bgColor: Color(hex: "#F2E8FA")!, borderColor: Color(hex: "#B97DF0")!, contentColor: Color(hex: "#64229E")!),
        DayConfig(id: "Sun", icon: "sun.max.fill", bgColor: Color(hex: "#FCEBEB")!, borderColor: Color(hex: "#F05353")!, contentColor: Color(hex: "#A11E1E")!)
    ]
    
    var body: some View {
        HStack(spacing: 8) {
            // Left Arrow
            Circle()
                .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                .background(Circle().fill(Color.white.opacity(0.8)))
                .frame(width: 30, height: 30)
                .overlay(Image(systemName: "chevron.left").font(.caption.bold()).foregroundColor(.orange))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(daysData, id: \.id) { day in
                        DayCardView(config: day, isSelected: selectedDays.contains(day.id)) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                if selectedDays.contains(day.id) {
                                    selectedDays.remove(day.id)
                                } else {
                                    selectedDays.insert(day.id)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
            
            // Right Arrow
            Circle()
                .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                .background(Circle().fill(Color.white.opacity(0.8)))
                .frame(width: 30, height: 30)
                .overlay(Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(.orange))
        }
    }
}

struct DayCardView: View {
    let config: DayConfig
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: config.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isSelected ? config.contentColor : .gray.opacity(0.4))
                
                Text(config.id)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(isSelected ? config.contentColor : .gray.opacity(0.6))
                
                // Status Dot
                Circle()
                    .fill(isSelected ? config.contentColor : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 65, height: 85)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? config.bgColor : Color.white.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? config.borderColor : Color.gray.opacity(0.2), lineWidth: 3)
            )
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

// MARK: - Challenge Card View (Compact Mode)

struct ChallengeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var accentColor: Color {
        isSelected ? Color(hex: "#A855F7") ?? .purple : Color(hex: "#9CA3AF") ?? .gray
    }
    var bgColor: Color {
        isSelected ? Color(hex: "#F3E8FF") ?? .purple.opacity(0.1) : .white.opacity(0.8)
    }
    var borderColor: Color {
        isSelected ? Color(hex: "#A855F7") ?? .purple : Color.white.opacity(0.5)
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                action()
            }
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(accentColor)
                
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(subtitle)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundColor(accentColor.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(bgColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected ? 3 : 1)
            )
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

// MARK: - Playful Analog Clock Components

struct ClockieHoldingDigitalClock: View {
    @Binding var date: Date
    @State private var showDatePicker: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .top) {
                BellsView()
                    .offset(y: -15)
                    .zIndex(1)
                
                ClockieFaceView(date: date)
                    .zIndex(2)
            }
            
            Spacer().frame(height: 20)
            
            DigitalDisplayWithPinsView(date: $date, showPicker: $showDatePicker)
                .zIndex(3)
                .offset(y: -10)
        }
        .sheet(isPresented: $showDatePicker) {
            ZStack {
                Color.orange.opacity(0.1).ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Pilih Waktu Alarm")
                        .font(.headline)
                        .padding(.top)
                    
                    DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .padding()
                    
                    Button("Selesai") {
                        showDatePicker = false
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
                }
            }
            .presentationDetents([.height(300)])
            .presentationCornerRadius(32)
        }
    }
}

struct ClockieFaceView: View {
    var date: Date
    let size: CGFloat = 220
    let darkColor = Color(hex: "#2C3E50") ?? .black

    var hourAngle: Double {
        let h = Double(Calendar.current.component(.hour, from: date))
        let m = Double(Calendar.current.component(.minute, from: date))
        return (h.truncatingRemainder(dividingBy: 12) + m / 60.0) * 30.0
    }

    var minuteAngle: Double {
        let m = Double(Calendar.current.component(.minute, from: date))
        return m * 6.0
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#FFF9EA") ?? .white)
                .overlay(Circle().stroke(Color(hex: "#E67E22") ?? .orange, lineWidth: 8))
                .frame(width: size, height: size)

            ForEach(0..<60) { i in
                let isHour = i % 5 == 0
                Rectangle()
                    .fill(Color(hex: "#E67E22") ?? .orange)
                    .frame(width: isHour ? 4 : 2, height: isHour ? 10 : 6)
                    .offset(y: -size/2 + 14)
                    .rotationEffect(.degrees(Double(i) * 6))
            }

            ForEach(1...12, id: \.self) { num in
                let angle = Double(num) * 30.0 * .pi / 180.0
                let radius = size/2 - 35
                Text("\(num)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "#D35400") ?? .orange)
                    .position(x: size/2 + CGFloat(sin(angle)) * radius,
                              y: size/2 - CGFloat(cos(angle)) * radius)
            }
            .frame(width: size, height: size)

            VStack(spacing: 12) {
                HStack(spacing: 28) {
                    EyeView()
                    EyeView()
                }
                
                SmileView()
                    .stroke(darkColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: 45, height: 18)
            }
            .offset(y: -5)

            Capsule()
                .fill(Color(hex: "#E67E22") ?? .orange)
                .frame(width: 8, height: size * 0.15)
                .offset(y: -size * 0.075)
                .rotationEffect(.degrees(hourAngle))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: date)

            Capsule()
                .fill(Color(hex: "#E67E22") ?? .orange)
                .frame(width: 5, height: size * 0.25)
                .offset(y: -size * 0.125)
                .rotationEffect(.degrees(minuteAngle))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: date)

            Circle()
                .stroke(Color(hex: "#E67E22") ?? .orange, lineWidth: 4)
                .background(Circle().fill(Color.white))
                .frame(width: 14, height: 14)
        }
        .shadow(color: .orange.opacity(0.15), radius: 10, y: 5)
    }
}

struct BellsView: View {
    let darkColor = Color(hex: "#2C3E50") ?? .black
    let yellowColor = Color(hex: "#FFD700") ?? .yellow
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(hex: "#FFCC80") ?? .orange)
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

struct EyeView: View {
    let darkColor = Color(hex: "#2C3E50") ?? .black
    var body: some View {
        Circle()
            .stroke(darkColor, lineWidth: 3)
            .background(Circle().fill(Color.white))
            .frame(width: 22, height: 22)
            .overlay(
                Circle()
                    .fill(darkColor)
                    .frame(width: 8, height: 8)
                    .offset(x: 2, y: 3)
            )
    }
}

struct SmileView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: 0),
                          control: CGPoint(x: rect.width/2, y: rect.height))
        return path
    }
}

struct DigitalDisplayWithPinsView: View {
    @Binding var date: Date
    @Binding var showPicker: Bool

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm"
        return formatter.string(from: date)
    }

    var amPmString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack(alignment: .top) {
                HStack {
                    PinHandShape().offset(x: 20, y: -10)
                    Spacer()
                    PinHandShape(reverse: true).offset(x: -20, y: -10)
                }
                .zIndex(2)

                Text(timeString)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#8C4310"))
                    .frame(width: 140, height: 70)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "#FAE1C5") ?? .white))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: "#E67E22") ?? .orange, lineWidth: 4))
            }
            .frame(width: 140)
            .onTapGesture {
                showPicker = true
            }

            ZStack(alignment: .top) {
                PinHandShape(isSinglePin: true).offset(y: -10).zIndex(2)

                Text(amPmString)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#6419E6"))
                    .frame(width: 70, height: 70)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "#F0E6FF") ?? .white))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: "#C29BFF") ?? .purple, lineWidth: 4))
            }
            .frame(width: 70)
            .onTapGesture {
                showPicker = true
            }
        }
    }
}

struct PinHandShape: View {
    var reverse: Bool = false
    var isSinglePin: Bool = false
    let darkColor = Color(hex: "#2C3E50") ?? .black

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(darkColor)
            .frame(width: isSinglePin ? 16 : 12, height: 24)
            .rotationEffect(.degrees(isSinglePin ? 0 : (reverse ? -10 : 10)))
    }
}

// MARK: - Miscellaneous Styles

struct SectionDivider: View {
    let title: String
    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.orange.opacity(0.3)).frame(height: 2)
            Text(title).font(.caption).bold().foregroundColor(.orange)
            Rectangle().fill(Color.orange.opacity(0.3)).frame(height: 2)
        }
    }
}

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Alarm Cell

struct AlarmCell: View {
    var alarm: Alarm
    var label: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let alertingTime = alarm.alertingTime {
                    Text(alertingTime, style: .time)
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                } else if let countdown = alarm.countdownDuration?.preAlert {
                    Text(countdown.customFormatted())
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                }

                Spacer(minLength: 12)
                tag
            }

            if !String(localized: label).isEmpty {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    var tag: some View {
        Text(tagLabel)
            .textCase(.uppercase)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tagColor.opacity(0.15))
            .foregroundStyle(tagColor)
            .clipShape(Capsule())
    }

    var tagLabel: String {
        switch alarm.state {
        case .scheduled: return "Scheduled"
        case .countdown: return "Running"
        case .paused: return "Paused"
        case .alerting: return "Alert"
        @unknown default: return "!"
        }
    }

    var tagColor: Color {
        switch alarm.state {
        case .scheduled: return .blue
        case .countdown: return .green
        case .paused: return .orange
        case .alerting: return .red
        @unknown default: return .gray
        }
    }
}
#Preview {
    ContentView()
}
