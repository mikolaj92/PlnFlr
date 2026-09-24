import CoreGraphics
import PlnFlrLayout
import SceneKit
import SwiftUI
#if os(macOS)
import AppKit
private typealias PreviewBezierPath = NSBezierPath
private typealias PreviewColor = NSColor
#else
import UIKit
private typealias PreviewBezierPath = UIBezierPath
private typealias PreviewColor = UIColor
#endif

struct Floor3DPreview: View {
    var plan: LayoutPlan
    var finish: FloorFinish
    var material: FloorMaterial = .plank

    var body: some View {
        SceneView(
            scene: Floor3DScene.make(plan: plan, finish: finish, material: material),
            options: [.allowsCameraControl, .autoenablesDefaultLighting],
            preferredFramesPerSecond: 30
        )
        .accessibilityLabel("Przestrzenny podgląd ułożenia podłogi")
    }
}

enum Floor3DScene {
    static func make(plan: LayoutPlan, finish: FloorFinish, material: FloorMaterial = .plank) -> SCNScene {
        let scene = SCNScene()
        let bounds = bbox(plan.room)
        let centerX = Double(bounds.minX + bounds.maxX) / 2
        let centerY = Double(bounds.minY + bounds.maxY) / 2
        let maximumExtent = Double(max(bounds.maxX - bounds.minX, bounds.maxY - bounds.minY))
        let modelScale = 4 / max(maximumExtent, 1)
        let floor = SCNNode()
        floor.name = "floor"
        scene.rootNode.addChildNode(floor)

        let roomOutline = PreviewBezierPath()
        append(plan.room.outer.vertices, to: roomOutline, centerX: centerX, centerY: centerY, scale: modelScale)
        for hole in plan.room.holes {
            append(hole.vertices, to: roomOutline, centerX: centerX, centerY: centerY, scale: modelScale)
        }
        let roomShape = SCNShape(path: roomOutline, extrusionDepth: 0.004)
        roomShape.chamferRadius = 0
        roomShape.firstMaterial?.diffuse.contents = PreviewColor(white: 0.88, alpha: 1)
        roomShape.firstMaterial?.isDoubleSided = true
        let roomNode = SCNNode(geometry: roomShape)
        roomNode.name = "floor.room-outline"
        roomNode.eulerAngles.x = -.pi / 2
        floor.addChildNode(roomNode)

        for parity in 0...1 {
            let rowGroups = Dictionary(grouping: plan.pieces.filter { $0.rowIndex.isMultiple(of: 2) == (parity == 0) }, by: \.rowIndex)
            let combinedPath = PreviewBezierPath()
            for row in rowGroups.keys.sorted() {
                for piece in rowGroups[row, default: []] {
                    append(piece.geometry, to: combinedPath, centerX: centerX, centerY: centerY, scale: modelScale)
                }
            }
            guard !combinedPath.isEmpty else { continue }
            let shape = SCNShape(path: combinedPath, extrusionDepth: 0.012)
            shape.chamferRadius = 0
            shape.firstMaterial?.diffuse.contents = color(finish, material: material, parity: parity)
            shape.firstMaterial?.isDoubleSided = true
            let node = SCNNode(geometry: shape)
            node.name = "floor.finish.\(parity)"
            node.eulerAngles.x = -.pi / 2
            node.position.y = 0.008
            floor.addChildNode(node)
        }

        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.name = "floor.camera"
        cameraNode.camera = camera
        let distance = Float(max(maximumExtent * modelScale * 1.7, 2.5))
        cameraNode.position = SCNVector3(0, distance, distance)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        camera.fieldOfView = 45
        scene.rootNode.addChildNode(cameraNode)
        scene.background.contents = CGColor(gray: 0.94, alpha: 1)
        return scene
    }

    private static func append(_ vertices: [Vertex], to path: PreviewBezierPath, centerX: Double, centerY: Double, scale: Double) {
        guard let first = vertices.first else { return }
        path.move(to: point(first, centerX: centerX, centerY: centerY, scale: scale))
        for vertex in vertices.dropFirst() {
            let position = point(vertex, centerX: centerX, centerY: centerY, scale: scale)
            #if os(macOS)
            path.line(to: position)
            #else
            path.addLine(to: position)
            #endif
        }
        path.close()
    }

    private static func point(_ vertex: Vertex, centerX: Double, centerY: Double, scale: Double) -> CGPoint {
        CGPoint(x: (Double(vertex.xMm) - centerX) * scale, y: (Double(vertex.yMm) - centerY) * scale)
    }

    private static func color(_ finish: FloorFinish, material: FloorMaterial, parity: Int) -> PreviewColor {
        switch (material, finish, parity) {
        case (.plank, .oak, 0): PreviewColor(red: 0.78, green: 0.60, blue: 0.37, alpha: 1)
        case (.plank, .oak, _): PreviewColor(red: 0.68, green: 0.48, blue: 0.27, alpha: 1)
        case (.plank, .walnut, 0): PreviewColor(red: 0.43, green: 0.28, blue: 0.20, alpha: 1)
        case (.plank, .walnut, _): PreviewColor(red: 0.33, green: 0.20, blue: 0.14, alpha: 1)
        case (.tile, _, 0): PreviewColor(red: 0.72, green: 0.72, blue: 0.68, alpha: 1)
        case (.tile, _, _): PreviewColor(red: 0.60, green: 0.62, blue: 0.60, alpha: 1)
        }
    }
}
