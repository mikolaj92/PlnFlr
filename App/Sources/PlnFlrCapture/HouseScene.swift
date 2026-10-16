import Foundation
import ModelIO
import SceneKit
import SceneKit.ModelIO
import simd
#if os(iOS)
import RoomPlan
import UIKit
#endif

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

    enum PreviewError: LocalizedError {
        case unreadable
        case roomPlanUnavailable
        case missingSource
        case emptySelection
        case missingNode(String)

        var errorDescription: String? {
            switch self {
            case .unreadable: "Nie udało się odczytać geometrii źródła."
            case .roomPlanUnavailable: "Podgląd RoomPlan wymaga iPhone’a lub iPada z API Apple."
            case .missingSource: "Brak zachowanego źródła 3D."
            case .emptySelection: "Wybierz co najmniej jeden element modelu."
            case .missingNode(let path): "Element źródła jest niedostępny: \(path)."
            }
        }
    }

    static func previewURL(_ scan: Workspace.Scan.State) throws -> URL {
        if let bytes = scan.sourceUsdz {
            let suffix = bytes.starts(with: [0x50, 0x4b]) ? "usdz" : "usd"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(suffix)")
            do {
                try bytes.write(to: url, options: .atomic)
                return url
            } catch {
                try? FileManager.default.removeItem(at: url)
                throw error
            }
        }
        #if os(iOS)
        if let source = scan.roomPlanStructure {
            return try RoomPlanStructurePreview.exportURL(source)
        }
        if let bytes = scan.roomPlanJSON {
            let room = try JSONDecoder().decode(RoomPlan.CapturedRoom.self, from: bytes)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).usdz")
            do {
                try room.export(to: url, exportOptions: .mesh)
                return url
            } catch {
                try? FileManager.default.removeItem(at: url)
                throw error
            }
        }
        #else
        if scan.roomPlanStructure != nil || scan.roomPlanJSON != nil {
            throw PreviewError.roomPlanUnavailable
        }
        #endif
        throw PreviewError.missingSource
    }

    private static func mesh(url: URL, transform: ScanTransform) throws -> SCNNode {
        let asset = MDLAsset(url: url)
        let node = SCNNode()
        node.name = "scan.mesh"
        for index in 0..<asset.count {
            node.addChildNode(SCNNode(mdlObject: asset.object(at: index)))
        }
        var hasGeometry = false
        node.enumerateChildNodes { child, _ in
            if let geometry = child.geometry, geometry.sources(for: .vertex).contains(where: { $0.vectorCount > 0 }) {
                hasGeometry = true
            }
        }
        guard hasGeometry else { throw PreviewError.unreadable }
        node.position = SCNVector3(CGFloat(transform.xMm) / 1000, CGFloat(transform.zMm) / 1000, CGFloat(transform.yMm) / 1000)
        node.eulerAngles = SCNVector3(0, Double(transform.yawDegrees % 360) * .pi / 180, 0)
        return node
    }

    public static func mesh(bytes: Data, transform: ScanTransform) -> SCNNode? {
        do {
            let scan = Workspace.Scan.State(id: UUID(), label: "", rooms: [], sourceUsdz: bytes)
            let url = try previewURL(scan)
            defer { try? FileManager.default.removeItem(at: url) }
            return try mesh(url: url, transform: transform)
        } catch {
            return nil
        }
    }

    #if os(iOS)
    struct WallAppearance {
        let geometry: SCNGeometry
        let materials: [SCNMaterial]

        func apply(color: UIColor?) {
            guard let color else {
                geometry.materials = materials
                return
            }
            geometry.materials = materials.map { original in
                let material = original.copy() as! SCNMaterial
                material.diffuse.contents = color
                return material
            }
        }
    }

    static func wallAppearances(_ scan: Workspace.Scan.State, in scene: SCNScene) throws -> [WallAppearance] {
        let identifiers = try RoomPlanStructurePreview.wallIdentifiers(scan)
        guard !identifiers.isEmpty,
              let root = scene.rootNode.childNode(withName: "scan.\(scan.id.uuidString)", recursively: false) else { return [] }
        let pattern = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
        var result: [WallAppearance] = []
        root.enumerateChildNodes { node, _ in
            guard let original = node.geometry else { return }
            var ancestor: SCNNode? = node
            while let candidate = ancestor, candidate !== root {
                if let name = candidate.name,
                   let range = name.range(of: pattern, options: .regularExpression),
                   let identifier = UUID(uuidString: String(name[range])) {
                    if identifiers.contains(identifier) {
                        let geometry = original.copy() as! SCNGeometry
                        node.geometry = geometry
                        result.append(WallAppearance(geometry: geometry, materials: original.materials))
                    }
                    break
                }
                ancestor = candidate.parent
            }
        }
        return result
    }
    #endif

    struct Element: Identifiable {
        var id: String
        var name: String
    }

    struct RoomSelection: Identifiable {
        var id: String
        var paths: [String]
    }

    private static func sourceNode(_ scan: Workspace.Scan.State) throws -> SCNNode {
        let url = try previewURL(scan)
        defer { try? FileManager.default.removeItem(at: url) }
        return try mesh(url: url, transform: scan.transform)
    }

    private static func indexedNodes(_ root: SCNNode) -> [(String, SCNNode)] {
        var result: [(String, SCNNode)] = []
        func visit(_ node: SCNNode, path: String) {
            for (index, child) in node.childNodes.enumerated() {
                let childPath = "\(path)/\(index)"
                result.append((childPath, child))
                visit(child, path: childPath)
            }
        }
        visit(root, path: "")
        return result
    }

    static func elements(_ scan: Workspace.Scan.State) throws -> [Element] {
        try indexedNodes(sourceNode(scan)).map { path, node in
            Element(id: path, name: "\(path) · \(node.name ?? "Element")")
        }
    }

    static func rooms(_ scan: Workspace.Scan.State) throws -> [RoomSelection] {
        let nodes = try indexedNodes(sourceNode(scan))
        let sources = scan.roomPlanStructure?.rooms ?? scan.roomPlanJSON.map { [$0] } ?? []
        return try sources.compactMap { data in
            guard let room = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = room["identifier"] as? String else { return nil }
            var identifiers = [id]
            for key in ["walls", "doors", "windows", "openings", "objects", "floors"] {
                let surfaces = room[key] as? [[String: Any]] ?? []
                identifiers.append(contentsOf: surfaces.compactMap { $0["identifier"] as? String })
            }
            let paths = nodes.compactMap { path, node -> String? in
                guard let name = node.name else { return nil }
                return identifiers.contains(where: { name.localizedCaseInsensitiveContains($0) }) ? path : nil
            }
            return paths.isEmpty ? nil : RoomSelection(id: id, paths: paths)
        }
    }

    private static func applySelection(_ paths: [String], to root: SCNNode) throws {
        guard !paths.isEmpty else { throw PreviewError.emptySelection }
        let nodes = indexedNodes(root)
        let available = Set(nodes.map(\.0))
        for path in paths where !available.contains(path) { throw PreviewError.missingNode(path) }
        for (path, node) in nodes {
            let included = paths.contains { path == $0 || path.hasPrefix($0 + "/") }
            let ancestor = paths.contains { $0.hasPrefix(path + "/") }
            node.isHidden = !included && !ancestor
            if !included { node.geometry = nil }
        }
    }

    static func validateSelection(_ scan: Workspace.Scan.State, paths: [String]) throws {
        try applySelection(paths, to: sourceNode(scan))
    }

    static func scans(_ scans: [Workspace.Scan.State], selection: [String]? = nil) -> (scene: SCNScene, errors: [String]) {
        let scene = SCNScene()
        var errors: [String] = []
        for scan in scans {
            do {
                let node = try sourceNode(scan)
                if let selection { try applySelection(selection, to: node) }
                node.name = "scan.\(scan.id.uuidString)"
                scene.rootNode.addChildNode(node)
            } catch {
                errors.append("\(scan.label): \(error.localizedDescription)")
            }
        }
        if !scene.rootNode.childNodes.isEmpty {
            let bounds = scene.rootNode.boundingBox
            let minimum = SIMD3<Double>(Double(bounds.min.x), Double(bounds.min.y), Double(bounds.min.z))
            let maximum = SIMD3<Double>(Double(bounds.max.x), Double(bounds.max.y), Double(bounds.max.z))
            let center = (minimum + maximum) / 2
            let radius = max(simd_length(maximum - minimum) / 2, 0.1)
            let distance = radius / sin(Double.pi / 8) * 1.2
            let camera = SCNNode()
            camera.name = "scans.camera"
            camera.camera = SCNCamera()
            camera.camera?.fieldOfView = 45
            camera.camera?.zNear = max(radius / 1000, 0.001)
            camera.camera?.zFar = distance + radius * 4
            camera.position = SCNVector3(center.x, center.y + distance / sqrt(2), center.z + distance / sqrt(2))
            camera.look(at: SCNVector3(center.x, center.y, center.z))
            scene.rootNode.addChildNode(camera)
        }
        return (scene, errors)
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
