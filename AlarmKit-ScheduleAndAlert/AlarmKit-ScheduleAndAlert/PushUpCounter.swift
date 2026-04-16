import Vision
import CoreGraphics

/// Push-up rep counter driven by `VNHumanBodyPoseObservation`.
/// Updated to use Trigonometry (Elbow Angle) for accurate tracking,
/// making it immune to camera distance changes.
final class PushUpCounter {
    enum Phase {
        case up
        case down
    }

    private(set) var reps: Int = 0
    private var phase: Phase = .up
    private var lastRepTime: CFTimeInterval = 0

    // Thresholds Angle (dalam Derajat, mengadaptasi logika Python-mu)
    private let downAngleThreshold: CGFloat = 90.0  // Siku menekuk
    private let upAngleThreshold: CGFloat = 160.0   // Siku lurus

    private let minConfidence: VNConfidence = 0.25
    private let minSecondsBetweenReps: CFTimeInterval = 0.45

    func reset() {
        reps = 0
        phase = .up
        lastRepTime = 0
    }

    /// Returns true if this call produced a new completed rep.
    @discardableResult
    func process(observation: VNHumanBodyPoseObservation, timestamp: CFTimeInterval) -> Bool {
        // Ambil sudut siku kiri (kamu bisa ubah ke kanan jika mau)
        guard let elbowAngle = getElbowAngle(observation: observation) else { return false }

        switch phase {
        case .up:
            // Badan Turun: Sudut siku lebih kecil dari 90 derajat
            if elbowAngle <= downAngleThreshold {
                phase = .down
            }
            return false

        case .down:
            // Badan Naik: Sudut siku lebih besar dari 160 derajat
            if elbowAngle >= upAngleThreshold {
                // Debounce (mencegah hitungan ganda / terlalu cepat)
                guard timestamp - lastRepTime >= minSecondsBetweenReps else {
                    phase = .up
                    return false
                }

                lastRepTime = timestamp
                reps += 1
                phase = .up
                return true
            }
            return false
        }
    }

    // Mengambil titik dari Vision dan menghitung sudutnya
    private func getElbowAngle(observation: VNHumanBodyPoseObservation) -> CGFloat? {
        do {
            let pts = try observation.recognizedPoints(.all)
            
            // Menggunakan lengan kiri sebagai patokan (sama seperti Python)
            guard let shoulder = pts[.leftShoulder],
                  let elbow = pts[.leftElbow],
                  let wrist = pts[.leftWrist] else {
                return nil
            }
            
            // Pastikan titiknya terdeteksi dengan jelas (confidence tinggi)
            guard shoulder.confidence >= minConfidence,
                  elbow.confidence >= minConfidence,
                  wrist.confidence >= minConfidence else {
                return nil
            }
            
            return calculateAngle(firstPoint: shoulder.location, midPoint: elbow.location, lastPoint: wrist.location)
        } catch {
            return nil
        }
    }
    
    // RUMUS TRIGONOMETRI: Menghitung sudut di antara 3 titik koordinat
    private func calculateAngle(firstPoint: CGPoint, midPoint: CGPoint, lastPoint: CGPoint) -> CGFloat {
        let dx1 = firstPoint.x - midPoint.x
        let dy1 = firstPoint.y - midPoint.y
        let dx2 = lastPoint.x - midPoint.x
        let dy2 = lastPoint.y - midPoint.y
        
        let angle1 = atan2(dy1, dx1)
        let angle2 = atan2(dy2, dx2)
        
        var angle = abs(angle1 - angle2) * 180.0 / .pi
        if angle > 180.0 {
            angle = 360.0 - angle
        }
        return angle
    }
}
