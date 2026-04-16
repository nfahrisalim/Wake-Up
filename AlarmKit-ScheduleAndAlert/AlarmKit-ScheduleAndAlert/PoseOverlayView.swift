import SwiftUI
import Vision


struct PosePoints: Equatable {
    var leftShoulder: CGPoint?
    var rightShoulder: CGPoint?
    
    var leftElbow: CGPoint?
    var rightElbow: CGPoint?
    
    var leftWrist: CGPoint?
    var rightWrist: CGPoint?
    
    var leftHip: CGPoint?
    var rightHip: CGPoint?
    
    var leftKnee: CGPoint?
    var rightKnee: CGPoint?

    var isEmpty: Bool {
        leftShoulder == nil && rightShoulder == nil && leftElbow == nil && rightElbow == nil && leftWrist == nil && rightWrist == nil
    }
}

struct PoseOverlayView: View {
    let pose: PosePoints

    /// Mirror horizontally to match a mirrored front camera preview.
    var isMirrored: Bool = true

    /// Simple styling.
    var lineColor: Color = .green // Diubah ke hijau agar lebih terlihat jelas
    var lineWidth: CGFloat = 4 // Dipertebal

    var body: some View {
        GeometryReader { proxy in
            // Canvas digunakan untuk menggambar performa tinggi
            Canvas { context, size in
                guard !pose.isEmpty else { return }

                // RUMUS RAHASIA: Konversi koordinat AI Vision ke koordinat layar HP
                func toView(_ p: CGPoint) -> CGPoint {

                    let y = (1 - p.y) * size.height
                    
                    var x = p.x * size.width
                    
                    if isMirrored {
                        x = size.width - x
                    }
                    return CGPoint(x: x, y: y)
                }

                // Fungsi bantuan menggambar garis
                func drawLine(_ a: CGPoint?, _ b: CGPoint?) {
                    guard let a, let b else { return }
                    var path = Path()
                    path.move(to: toView(a))
                    path.addLine(to: toView(b))
                    context.stroke(path, with: .color(lineColor), lineWidth: lineWidth)
                }

                // Fungsi bantuan menggambar titik
                func drawDot(_ p: CGPoint?, radius: CGFloat = 6) {
                    guard let p else { return }
                    let center = toView(p)
                    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(lineColor))
                }

                // --- BAGIAN INI YANG MEMBUAT GARIS MENGIKUTI TANGAN ---
                
                // 1. Gambar Garis Lengan Kiri (Bahu -> Siku -> Pergelangan Tangan)
                drawLine(pose.leftShoulder, pose.leftElbow)
                drawLine(pose.leftElbow, pose.leftWrist)
                
                // 2. Gambar Garis Lengan Kanan (Bahu -> Siku -> Pergelangan Tangan)
                drawLine(pose.rightShoulder, pose.rightElbow)
                drawLine(pose.rightElbow, pose.rightWrist)
                
                // 3. Gambar Garis Badan Atas (Bahu Kiri -> Bahu Kanan)
                drawLine(pose.leftShoulder, pose.rightShoulder)

                // 4. Gambar Titik Merah (Markers) agar terlihat jelas sendinya
                drawDot(pose.leftWrist, radius: 7)
                drawDot(pose.rightWrist, radius: 7)
                drawDot(pose.leftElbow, radius: 5)
                drawDot(pose.rightElbow, radius: 5)
                drawDot(pose.leftShoulder, radius: 5)
                drawDot(pose.rightShoulder, radius: 5)
            }
            .allowsHitTesting(false) // Overlay tidak boleh menghalangi sentuhan layar
        }
    }
}
