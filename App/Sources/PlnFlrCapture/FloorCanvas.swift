import PlnFlrLayout
import SwiftUI

struct FloorCanvas: View {
    var plan: LayoutPlan
    var finish: FloorFinish = .oak
    var material: FloorMaterial = .plank

    var body: some View {
        Canvas { context, size in
            let bounds = bbox(plan.room)
            let width = max(CGFloat(bounds.maxX - bounds.minX), 1)
            let height = max(CGFloat(bounds.maxY - bounds.minY), 1)
            let scale = min(size.width / width, size.height / height)
            func point(_ v: Vertex) -> CGPoint {
                CGPoint(
                    x: CGFloat(v.xMm - bounds.minX) * scale,
                    y: size.height - CGFloat(v.yMm - bounds.minY) * scale
                )
            }
            var outline = path(plan.room.outer.vertices, point)
            for hole in plan.room.holes { outline.addPath(path(hole.vertices, point)) }
            context.fill(outline, with: .color(.secondary.opacity(0.15)), style: FillStyle(eoFill: true))
            for piece in plan.pieces {
                let color = Color(hex: material == .tile ? stonePreviewColors[piece.rowIndex.isMultiple(of: 2) ? 0 : 1] : finish.previewColors[piece.rowIndex.isMultiple(of: 2) ? 0 : 1])
                context.fill(path(piece.geometry, point), with: .color(color.opacity(0.88)))
                context.stroke(path(piece.geometry, point), with: .color(.primary.opacity(0.4)), lineWidth: 0.5)
            }
            for window in plan.windows {
                var line = Path()
                line.move(to: point(window.start))
                line.addLine(to: point(window.end))
                context.stroke(line, with: .color(.blue), lineWidth: 3)
            }
        }
        .accessibilityLabel("Plan ułożenia podłogi")
    }

    private func path(_ vertices: [Vertex], _ point: (Vertex) -> CGPoint) -> Path {
        var p = Path()
        guard let first = vertices.first else { return p }
        p.move(to: point(first))
        for v in vertices.dropFirst() {
            p.addLine(to: point(v))
        }
        p.closeSubpath()
        return p
    }
}

private let stonePreviewColors = ["#B8B9B3", "#999D99"]

private extension Color {
    init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0xC69A62
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255,
            opacity: 1
        )
    }
}
