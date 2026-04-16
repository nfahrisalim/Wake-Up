import AVFoundation

final class InAppAlarmSoundPlayer {
    static let shared = InAppAlarmSoundPlayer()

    private var player: AVAudioPlayer?
    private var sfxPlayer: AVAudioPlayer?

    private init() {}

    func startLoopingAlarmSound() {
        guard player?.isPlaying != true else { return }

        guard let url = Bundle.main.url(forResource: "alarm", withExtension: "wav") else {
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use playback so it can continue in silent mode while app is foreground.
            // Keep .duckOthers so the alarm has priority over other audio.
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)

            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
            // Best-effort; if it fails, we just won't have in-app fallback audio.
            player = nil
        }
    }

    /// Plays a short sound effect once without stopping the looping alarm.
    func playOneShotSFX(resource: String, withExtension ext: String) {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            return
        }

        do {
            // Reuse the active session from the alarm if present.
            // If something calls this before the alarm loop starts, activate playback.
            let audioSession = AVAudioSession.sharedInstance()
            if !audioSession.isOtherAudioPlaying {
                try? audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            }
            try? audioSession.setActive(true)

            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = 0
            p.volume = 1.0
            p.prepareToPlay()
            p.play()
            sfxPlayer = p
        } catch {
            sfxPlayer = nil
        }
    }

    /// Pause the looping alarm sound if it's currently playing.
    /// This doesn't clear the player so it can resume smoothly.
    func pauseAlarmLoop() {
        guard let player, player.isPlaying else { return }
        player.pause()
    }

    /// Resume the looping alarm sound if it exists and is paused.
    /// If the player is nil (never started / was stopped), this does nothing.
    func resumeAlarmLoopIfNeeded() {
        guard let player else { return }
        guard !player.isPlaying else { return }
        player.play()
    }

    func stop() {
        player?.stop()
        player = nil

        sfxPlayer?.stop()
        sfxPlayer = nil

        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
