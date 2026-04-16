import SwiftUI
import AVFoundation
import Vision

// MARK: - 1. MAIN UI VIEW (Tampilan Layar)
struct PushUpGameView: View {
    var targetReps: Int
    var onComplete: () -> Void
    var onFallbackToTapping: (() -> Void)? = nil

    @StateObject private var camera = CameraPoseController()

    @State private var isShowingJumpScare = false
    @State private var jumpScareTask: Task<Void, Never>?
    @State private var lastJumpScareAt = Date.distantPast
    @State private var hasShownCompletionJumpScare = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Menampilkan Kamera
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            // Menampilkan Titik Pose (Garis tubuh)
            PoseOverlayView(pose: camera.posePoints, isMirrored: true)
                .ignoresSafeArea()

            LinearGradient(colors: [Color.black.opacity(0.65), .clear, Color.black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text("PUSH-UPS")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))

                    Text("\(camera.reps) / \(targetReps)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(camera.statusText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                }
                .padding(.top, 22)

                Spacer()

                if camera.authorizationState == .denied || camera.authorizationState == .restricted {
                    VStack(spacing: 10) {
                        Text("Camera permission is required for push-ups.")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))

                        if let onFallbackToTapping {
                            Button {
                                onFallbackToTapping()
                            } label: {
                                Text("Use tapping game")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.cyan)
                            .controlSize(.large)
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                } else {
                    Text("Keep your upper body visible. Go down then up to count 1 rep.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.bottom, 22)
                }
            }
            .allowsHitTesting(!isShowingJumpScare)

            if isShowingJumpScare {
                JumpScareOverlayView(isPresented: $isShowingJumpScare)
                    .transition(.opacity)
                    .zIndex(1000)
            }
        }
        .onAppear {
            camera.target = max(1, min(targetReps, 20))

            camera.onComplete = {
                Task { @MainActor in
                    guard !hasShownCompletionJumpScare else {
                        onComplete()
                        return
                    }

                    hasShownCompletionJumpScare = true
                    lastJumpScareAt = Date()
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isShowingJumpScare = true
                    }

                    try? await Task.sleep(nanoseconds: 5_200_000_000)
                    onComplete()
                }
            }
            camera.start()
        }
        .onDisappear {
            jumpScareTask?.cancel()
            jumpScareTask = nil
            camera.stop()
        }
    }
}

// MARK: - 5. KONTROLER KAMERA & VISION
final class CameraPoseController: NSObject, ObservableObject {
    enum AuthState { case notDetermined, authorized, denied, restricted }

    // Session
    let session = AVCaptureSession()

    // Public state
    @MainActor @Published var reps: Int = 0
    @MainActor @Published var statusText: String = "Getting ready…"
    @MainActor @Published var authorizationState: AuthState = .notDetermined
    @MainActor @Published var posePoints: PosePoints = .init()

    // Config
    var target: Int = 8
    var onComplete: (() -> Void)?

    // Internals
    private let counter = PushUpCounter()
    private let visionQueue = DispatchQueue(label: "vision.queue.pushups")
    private var isProcessing = false

    override init() {
        super.init()
        configureSession()
        checkPermission()
    }

    func start() {
        if !session.isRunning {
            session.startRunning()
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            Task { @MainActor in self.authorizationState = .authorized }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in self.authorizationState = granted ? .authorized : .denied }
            }
        case .denied:
            Task { @MainActor in self.authorizationState = .denied }
        case .restricted:
            Task { @MainActor in self.authorizationState = .restricted }
        @unknown default:
            Task { @MainActor in self.authorizationState = .restricted }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if let conn = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                conn.videoRotationAngle = 0
            } else {
                conn.videoOrientation = .portrait
            }
            conn.isVideoMirrored = true
        }

        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
        session.commitConfiguration()
    }
}

extension CameraPoseController: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CACurrentMediaTime()

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
            guard let observation = request.results?.first else {
                Task { @MainActor in
                    self.statusText = "No body detected."
                    self.posePoints = .init()
                }
                return
            }

            let didRep = counter.process(observation: observation, timestamp: timestamp)
            let pose = Self.extractPosePoints(from: observation)

            Task { @MainActor in
                self.posePoints = pose
                self.reps = counter.reps
                self.statusText = didRep ? "Good!" : "Keep going…"

                if self.reps >= self.target {
                    self.stop()
                    self.onComplete?()
                }
            }
        } catch {
            Task { @MainActor in
                self.statusText = "Vision error."
                self.posePoints = .init()
            }
        }
    }
}

extension CameraPoseController {
    nonisolated static func extractPosePoints(from observation: VNHumanBodyPoseObservation) -> PosePoints {
        do {
            let pts = try observation.recognizedPoints(.all)

            func point(_ key: VNHumanBodyPoseObservation.JointName, minConfidence: VNConfidence = 0.25) -> CGPoint? {
                guard let p = pts[key], p.confidence >= minConfidence else { return nil }
                return p.location
            }

            return PosePoints(
                leftShoulder: point(.leftShoulder),
                rightShoulder: point(.rightShoulder),
                leftElbow: point(.leftElbow),
                rightElbow: point(.rightElbow),
                leftWrist: point(.leftWrist),
                rightWrist: point(.rightWrist),
                leftHip: point(.leftHip),
                rightHip: point(.rightHip),
                leftKnee: point(.leftKnee),
                rightKnee: point(.rightKnee)
            )
        } catch {
            return .init()
        }
    }
}

// MARK: - 6. PREVIEW KAMERA DASAR
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

#Preview {
    PushUpGameView(targetReps: 8, onComplete: {})
}
