/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The main entry point of the iOS app.
*/

import SwiftUI

@main
struct AlarmKitScheduleAndAlertApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

private struct RootView: View {
    @State private var coordinator = AlarmStopCoordinator.shared

    var body: some View {
        ContentView()
            // When Stop/Open is tapped from the Live Activity, the intent runs in the extension.
            // We bridge that to the app with a Notification and start the stop-flow here.
            .onReceive(NotificationCenter.default.publisher(for: .alarmStopFlowRequested)) { note in
                if let id = note.object as? UUID {
                    coordinator.requestStopFlow(for: id)
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { coordinator.pendingStopAlarmID != nil },
                set: { shouldShow in
                    if !shouldShow {
                        InAppAlarmSoundPlayer.shared.stop()
                        coordinator.cancel()
                    }
                }
            )) {
                stopGame
                    .onAppear {
                        InAppAlarmSoundPlayer.shared.startLoopingAlarmSound()
                    }
                    .onDisappear {
                        InAppAlarmSoundPlayer.shared.stop()
                    }
            }
    }

    @ViewBuilder
    private var stopGame: some View {
        switch coordinator.selectedGame {
        case .tapping:
            TappingGameView {
                InAppAlarmSoundPlayer.shared.stop()
                coordinator.completeStopIfNeeded()
            }
        case .pushUps:
            PushUpGameView(
                targetReps: coordinator.pushUpTarget,
                onComplete: {
                    InAppAlarmSoundPlayer.shared.stop()
                    coordinator.completeStopIfNeeded()
                },
                onFallbackToTapping: {
                    coordinator.selectedGame = .tapping
                }
            )
        }
    }
}
