import Foundation
import ModelIO
import SceneKit
import SceneKit.ModelIO
import simd

public struct ScenePoint: Codable, Equatable, Sendable {
    public var xMm: Int
    public var yMm: Int
    public var zMm: Int
    public init(xMm: Int, yMm: Int, zMm: Int) {
        self.xMm = xMm
        self.yMm = yMm
        self.zMm = zMm
    }
}

public enum RecordState: String, Codable, Equatable, Sendable { case existing, planned }
public enum UtilitySource: String, Codable, Equatable, Sendable { case measurement, discovery, document, photo, other }
public enum UtilityConfidence: String, Codable, Equatable, Sendable { case confirmed, approximate, unverified }

public struct WallSegment: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var start: ScenePoint
    public var end: ScenePoint
    public var heightMm: Int
    public var finish: String
    public init(id: UUID, start: ScenePoint, end: ScenePoint, heightMm: Int, finish: String) {
        self.id = id
        self.start = start
        self.end = end
        self.heightMm = heightMm
        self.finish = finish
    }
}

public struct UtilityRoute: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var colorName: String
    public var diameterMm: Int
    public var points: [ScenePoint]
    public var state: RecordState
    public var source: UtilitySource
    public var confidence: UtilityConfidence
    public init(id: UUID, name: String, colorName: String, diameterMm: Int, points: [ScenePoint], state: RecordState, source: UtilitySource, confidence: UtilityConfidence) {
        self.id = id
        self.name = name
        self.colorName = colorName
        self.diameterMm = diameterMm
        self.points = points
        self.state = state
        self.source = source
        self.confidence = confidence
    }
}

public struct FurnitureItem: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var size: ScenePoint
    public var origin: ScenePoint
    public var state: RecordState
    public var hidden: Bool
    public init(id: UUID, name: String, size: ScenePoint, origin: ScenePoint, state: RecordState, hidden: Bool = false) {
        self.id = id
        self.name = name
        self.size = size
        self.origin = origin
        self.state = state
        self.hidden = hidden
    }
}

public struct DrillQuery: Equatable, Sendable {
    public var origin: ScenePoint
    public var direction: ScenePoint
    public var depthMm: Int
}

public struct DrillHit: Equatable, Sendable {
    public var routeID: UUID
    public var name: String
    public var source: UtilitySource
    public var confidence: UtilityConfidence
}

public enum DrillAnswer: Equatable, Sendable {
    case unknown
    case hits([DrillHit])
}

public enum HouseScene {
    public static func drill(_ query: DrillQuery, routes: [UtilityRoute]) -> DrillAnswer {
        guard !routes.isEmpty else { return .unknown }
        let depth = max(query.depthMm, 0)
        let direction = simd_double3(Double(query.direction.xMm), Double(query.direction.yMm), Double(query.direction.zMm))
        let length = simd_length(direction)
        guard length > 0 else { return .unknown }
        let unit = direction / length
        let origin = simd_double3(Double(query.origin.xMm), Double(query.origin.yMm), Double(query.origin.zMm))
        var hits: [DrillHit] = []
        for route in routes {
            let radius = Double(route.diameterMm) / 2
            let struck = route.points.contains { point in
                let candidate = simd_double3(Double(point.xMm), Double(point.yMm), Double(point.zMm)) - origin
                let along = simd_dot(candidate, unit)
                guard along >= 0, along <= Double(depth) else { return false }
                return simd_length(candidate - unit * along) <= radius
            }
            if struck {
                hits.append(DrillHit(routeID: route.id, name: route.name, source: route.source, confidence: route.confidence))
            }
        }
        return .hits(hits)
    }

    public static func mesh(bytes: Data, transform: ScanTransform) -> SCNNode? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".usd")
        do {
            try bytes.write(to: url)
            defer { try? FileManager.default.removeItem(at: url) }
            let asset = MDLAsset(url: url)
            guard asset.count > 0 else { return nil }
            let node = SCNNode(mdlObject: asset.object(at: 0))
            node.name = "scan.mesh"
            node.position = SCNVector3(CGFloat(transform.xMm) / 1000, CGFloat(transform.zMm) / 1000, CGFloat(transform.yMm) / 1000)
            node.eulerAngles.y = CGFloat(transform.yawDegrees) * .pi / 180
            return node
        } catch {
            return nil
        }
    }

    public static func scene(walls: [WallSegment], routes: [UtilityRoute], furniture: [FurnitureItem]) -> SCNScene {
        let scene = SCNScene()
        for wall in walls {
            let node = SCNNode(geometry: SCNBox(width: span(wall) / 1000, height: Double(wall.heightMm) / 1000, length: 0.1, chamferRadius: 0))
            node.name = "wall.\(wall.id.uuidString)"
            node.geometry?.firstMaterial?.diffuse.contents = wall.finish
            scene.rootNode.addChildNode(node)
        }
        for route in routes {
            let node = SCNNode()
            node.name = "utility.\(route.id.uuidString).\(route.confidence.rawValue)"
            scene.rootNode.addChildNode(node)
        }
        for item in furniture where !item.hidden {
            let node = SCNNode(geometry: SCNBox(width: Double(item.size.xMm) / 1000, height: Double(item.size.zMm) / 1000, length: Double(item.size.yMm) / 1000, chamferRadius: 0))
            node.name = "furniture.\(item.id.uuidString)"
            node.position = SCNVector3(Double(item.origin.xMm) / 1000, Double(item.origin.zMm) / 1000, Double(item.origin.yMm) / 1000)
            scene.rootNode.addChildNode(node)
        }
        return scene
    }

    private static func span(_ wall: WallSegment) -> Double {
        let dx = Double(wall.end.xMm - wall.start.xMm)
        let dy = Double(wall.end.yMm - wall.start.yMm)
        return max(simd_length(simd_double2(dx, dy)), 1)
    }
}
