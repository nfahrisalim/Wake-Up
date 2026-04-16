import SwiftUI

#if os(iOS) && !WIDGET_EXTENSION
import UIKit


struct JumpScareOverlayView: View {
    @Binding var isPresented: Bool

    private let minimumDisplaySeconds: TimeInterval = 5

    @State private var canDismiss = false

    private var jumpUIImage: UIImage? {
        // Prefer loading as a file resource.
        if let path = Bundle.main.path(forResource: "jump", ofType: "jpg"),
           let img = UIImage(contentsOfFile: path) {
            return img
        }

        // Fallbacks (in case the resource gets moved into Assets later).
        if let img = UIImage(named: "jump") { return img }
        if let img = UIImage(named: "jump.jpg") { return img }
        return nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let uiImage = jumpUIImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                // Loud, visible debug state so it's obvious the resource isn't bundled.
                VStack(spacing: 12) {
                    Text("Missing resource")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("jump.jpg not found in app bundle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Expected: Copy Bundle Resources -> jump.jpg")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .multilineTextAlignment(.center)
                .padding(16)
                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding()
            }

            if !canDismiss {
                VStack {
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard canDismiss else { return }
            isPresented = false
        }
        .onChange(of: isPresented) { _, newValue in
            // When dismissed (e.g. parent toggles binding), bring alarm loop back.
            if !newValue {
                InAppAlarmSoundPlayer.shared.resumeAlarmLoopIfNeeded()
            }
        }
        .onAppear {
            canDismiss = false

            // Requirement: pause alarm.wav whenever jump scare shows.
            InAppAlarmSoundPlayer.shared.pauseAlarmLoop()

            InAppAlarmSoundPlayer.shared.playOneShotSFX(resource: "scream", withExtension: "mp3")

            // Enforce minimum visible time.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(minimumDisplaySeconds * 1_000_000_000))
                canDismiss = true
            }
        }
        .onDisappear {
            // Defensive: if the view disappears without the binding change firing, resume.
            InAppAlarmSoundPlayer.shared.resumeAlarmLoopIfNeeded()
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("Jump scare")
    }
}

#Preview {
    JumpScareOverlayView(isPresented: .constant(true))
}
#else
/// Minimal placeholder used when compiling inside the Widget/LiveActivity extension.
/// The extension should never need this view, but keeping a stub avoids build breaks
/// if an app-only source file is accidentally added to the extension target.
struct JumpScareOverlayView: View {
    @Binding var isPresented: Bool

    var body: some View {
        EmptyView()
    }
}
#endif
