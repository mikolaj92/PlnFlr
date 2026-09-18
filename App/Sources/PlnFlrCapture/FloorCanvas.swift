import PlnFlrLayout
import SwiftUI

struct FloorCanvas: View {
    var plan: LayoutPlan

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
            context.fill(path(plan.room.outer.vertices, point), with: .color(.secondary.opacity(0.15)))
            for hole in plan.room.holes {
                context.fill(path(hole.vertices, point), with: .color(.white))
            }
            for piece in plan.pieces {
                let color: Color = piece.rowIndex.isMultiple(of: 2)
                    ? Color.orange.opacity(0.55)
                    : Color.brown.opacity(0.45)
                context.fill(path(piece.geometry, point), with: .color(color))
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
