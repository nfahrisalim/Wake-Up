/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A list of intents the app uses to manage the alarm state.
*/

import AlarmKit
import AppIntents

// Add a simple cross-target signal the extension can send and the app can receive.
extension Notification.Name {
    static let alarmStopFlowRequested = Notification.Name("alarmStopFlowRequested")
}

struct PauseIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        try AlarmManager.shared.pause(id: UUID(uuidString: alarmID)!)
        return .result()
    }
    
    static var title: LocalizedStringResource = "Pause"
    static var description = IntentDescription("Pause a countdown")
    
    @Parameter(title: "alarmID")
    var alarmID: String
    
    init(alarmID: String) {
        self.alarmID = alarmID
    }
    
    init() {
        self.alarmID = ""
    }
}

struct StopIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }

        // IMPORTANT: Don't stop from the notification / Live Activity directly.
        // Always route through the app and gate the real stop behind the mini game.
#if canImport(WidgetKit)
        // Live Activity extension build: signal the app to present the mini game.
        // `openAppWhenRun = true` will bring the app to foreground.
        NotificationCenter.default.post(name: .alarmStopFlowRequested, object: id)
#else
        // Main app build: start stop-flow UI.
        AlarmStopCoordinator.shared.requestStopFlow(for: id)
#endif
        return .result()
    }

    static var title: LocalizedStringResource = "Open"
    static var description = IntentDescription("Open the app to stop the alarm")
    static var openAppWhenRun = true

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }
}

struct RepeatIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        try AlarmManager.shared.countdown(id: UUID(uuidString: alarmID)!)
        return .result()
    }
    
    static var title: LocalizedStringResource = "Repeat"
    static var description = IntentDescription("Repeat a countdown")
    
    @Parameter(title: "alarmID")
    var alarmID: String
    
    init(alarmID: String) {
        self.alarmID = alarmID
    }
    
    init() {
        self.alarmID = ""
    }
}

struct ResumeIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        try AlarmManager.shared.resume(id: UUID(uuidString: alarmID)!)
        return .result()
    }
    
    static var title: LocalizedStringResource = "Resume"
    static var description = IntentDescription("Resume a countdown")
    
    @Parameter(title: "alarmID")
    var alarmID: String
    
    init(alarmID: String) {
        self.alarmID = alarmID
    }
    
    init() {
        self.alarmID = ""
    }
}

struct OpenAlarmAppIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
#if canImport(WidgetKit)
        NotificationCenter.default.post(name: .alarmStopFlowRequested, object: id)
        return .result()
#else
        AlarmStopCoordinator.shared.requestStopFlow(for: id)
        return .result()
#endif
    }
    
    static var title: LocalizedStringResource = "Open App"
    static var description = IntentDescription("Opens the Sample app")
    static var openAppWhenRun = true
    
    @Parameter(title: "alarmID")
    var alarmID: String
    
    init(alarmID: String) {
        self.alarmID = alarmID
    }
    
    init() {
        self.alarmID = ""
    }
}
