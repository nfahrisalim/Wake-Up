import AlarmKit
import Observation

@Observable
final class AlarmStopCoordinator {
    static let shared = AlarmStopCoordinator()

    enum StopGame: String, Codable {
        case tapping
        case pushUps
    }

    /// User-selectable preference for which mini game to show when stopping an alarm.
    enum StopGamePreference: String, CaseIterable, Codable {
        case tapping
        case pushUps
        case random

        static let storageKey = "stopGamePreference"
    }

    // The alarm we want to stop, but only after the game is completed.
    var pendingStopAlarmID: UUID?

    // Which game should be played for the current stop flow.
    var selectedGame: StopGame = .tapping

    // Only used when `selectedGame == .pushUps`
    var pushUpTarget: Int = 8

    private init() {}

    /// Reads the persisted preference from UserDefaults.
    var preferredGame: StopGamePreference {
        get {
            let raw = UserDefaults.standard.string(forKey: StopGamePreference.storageKey)
            return StopGamePreference(rawValue: raw ?? "") ?? .random
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: StopGamePreference.storageKey)
        }
    }

    func requestStopFlow(for alarmID: UUID) {
        pendingStopAlarmID = alarmID

        switch preferredGame {
        case .tapping:
            selectedGame = .tapping

        case .pushUps:
            selectedGame = .pushUps
            pushUpTarget = 8

        case .random:
            // Default slightly towards tapping (less setup friction), but still random.
            if Double.random(in: 0...1) < 0.25 {
                selectedGame = .pushUps
                pushUpTarget = 8
            } else {
                selectedGame = .tapping
            }
        }
    }

    func completeStopIfNeeded() {
        guard let id = pendingStopAlarmID else { return }
        pendingStopAlarmID = nil
        try? AlarmManager.shared.stop(id: id)
    }

    func cancel() {
        pendingStopAlarmID = nil
    }
}
