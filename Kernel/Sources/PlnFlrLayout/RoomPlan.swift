import Foundation

public struct CapturedScan: Sendable {
    public var name: String
    public var room: Room
    public var thresholds: [Threshold]
    public var verticesM: String
    public var holeRectangles: String
    public var doorVertices: String
    public var windows: [Opening]
    public var windowSegments: String
}

private let thresholdMm = 80
private let topZ = 0.02
private let roomNames: [String: String] = [
    "livingroom": "Salon",
    "bedroom": "Sypialnia",
    "bathroom": "Łazienka",
    "kitchen": "Kuchnia",
    "diningroom": "Jadalnia",
]

public func roomFromUsdz(_ payload: Data) throws -> CapturedScan {
    let archive: ZipArchive
    do {
        archive = try ZipArchive(data: payload)
    } catch {
        throw ScanError.notZip
    }
    let names = archive.names
    guard names.contains("Scan.usda") || names.contains("./Scan.usda") else {
        throw ScanError.notRoomPlan
    }
    let floors = names.filter { $0.contains("/Floors/Floor") && $0.hasSuffix(".usda") }
    guard let floorName = floors.first, let floorData = archive[floorName],
          let floorText = String(data: floorData, encoding: .utf8)
    else { throw ScanError.missingFloor }
    let floor = try parseUsdaMesh(floorText, name: "Floor")
    let outlineM = try floorOutlineM(floor)
    let origin = (
        outlineM.map(\.0).min() ?? 0,
        outlineM.map(\.1).min() ?? 0
    )
    let outer = try ringMm(outlineM, origin: origin)
    var fireplaces: [Ring] = []
    var fireplaceRects: [String] = []
    var thresholds: [Threshold] = []
    var doorPolys: [String] = []
    var windows: [Opening] = []
    for name in names {
        guard name.hasSuffix(".usda"), name.contains("/Mesh/") else { continue }
        guard let bytes = archive[name], let text = String(data: bytes, encoding: .utf8) else { continue }
        let leaf = name.split(separator: "/").last.map { String($0.replacingOccurrences(of: ".usda", with: "")) } ?? name
        let mesh = try parseUsdaMesh(text, name: leaf)
        let category = mesh.category.lowercased()
        if category.hasPrefix("fireplace") {
            let (ring, rect) = try boxRing(mesh, origin: origin)
            fireplaces.append(ring)
            fireplaceRects.append(rect)
        } else if category.hasPrefix("door") {
            let threshold = try doorThreshold(mesh, origin: origin)
            thresholds.append(threshold)
            doorPolys.append(ringToVerticesM(threshold.geometry))
        } else if category.hasPrefix("window") {
            windows.append(try windowOpening(mesh, origin: origin))
        }
    }
    let holes = fireplaces + thresholds.map(\.geometry)
    let scanText = String(data: archive["Scan.usda"] ?? archive["./Scan.usda"] ?? Data(), encoding: .utf8) ?? ""
    return CapturedScan(
        name: roomName(scanText),
        room: Room(outer, holes: holes),
        thresholds: thresholds,
        verticesM: ringToVerticesM(outer),
        holeRectangles: fireplaceRects.joined(separator: "\n"),
        doorVertices: doorPolys.joined(separator: "\n\n"),
        windows: windows,
        windowSegments: windows.map(openingToSegmentM).joined(separator: "\n")
    )
}

private func roomName(_ root: String) -> String {
    let lower = root.lowercased()
    for (key, label) in roomNames where lower.contains("\(key)0") {
        return label
    }
    return "Pokój"
}

private func floorOutlineM(_ floor: UsdaMesh) throws -> [(Double, Double)] {
    let top = floor.points.indices.filter { abs(floor.points[$0].2) <= topZ }
    let topSet = Set(top)
    guard top.count >= 3 else { throw ScanError.noFloorPlane }
    var cursor = 0
    var edgeCount: [Set<Int>: Int] = [:]
    for count in floor.counts {
        let face = Array(floor.indices[cursor..<(cursor + count)])
        cursor += count
        guard count == 3, face.allSatisfy({ topSet.contains($0) }) else { continue }
        for pair in [(face[0], face[1]), (face[1], face[2]), (face[2], face[0])] {
            let key: Set<Int> = [pair.0, pair.1]
            edgeCount[key, default: 0] += 1
        }
    }
    var boundary: [Int: [Int]] = [:]
    for (edge, seen) in edgeCount where seen == 1 {
        let nodes = Array(edge)
        guard nodes.count == 2 else { continue }
        boundary[nodes[0], default: []].append(nodes[1])
        boundary[nodes[1], default: []].append(nodes[0])
    }
    guard !boundary.isEmpty else { throw ScanError.noOutline }
    let start = boundary.keys.min { a, b in
        let pa = plan(floor, a), pb = plan(floor, b)
        if pa.0 != pb.0 { return pa.0 < pb.0 }
        if pa.1 != pb.1 { return pa.1 < pb.1 }
        return a < b
    }!
    var walked = [start]
    var previous = start
    var current = boundary[start]![0]
    while current != start {
        walked.append(current)
        guard let nxt = boundary[current]?.first(where: { $0 != previous }) else {
            throw ScanError.brokenOutline
        }
        previous = current
        current = nxt
        if walked.count > floor.points.count { throw ScanError.brokenOutline }
    }
    return walked.map { plan(floor, $0) }
}

private func plan(_ mesh: UsdaMesh, _ index: Int) -> (Double, Double) {
    let world = transformPoint(mesh.points[index], matrix: mesh.matrix)
    return (world.0, world.2)
}

private func boxCornersM(_ mesh: UsdaMesh) throws -> [(Double, Double)] {
    var seen = Set<String>()
    var corners: [(Double, Double)] = []
    for point in mesh.points {
        let world = transformPoint((point.0, 0.0, point.2), matrix: mesh.matrix)
        let key = String(format: "%.4f,%.4f", world.0, world.2)
        if seen.contains(key) { continue }
        seen.insert(key)
        corners.append((world.0, world.2))
    }
    if corners.count < 3 { throw ScanError.noPlan(mesh.name) }
    return corners
}

private func orderedRingM(_ points: [(Double, Double)]) -> [(Double, Double)] {
    let cx = points.map(\.0).reduce(0, +) / Double(points.count)
    let cy = points.map(\.1).reduce(0, +) / Double(points.count)
    return points.sorted { atan2($0.1 - cy, $0.0 - cx) < atan2($1.1 - cy, $1.0 - cx) }
}

private func boxRing(_ mesh: UsdaMesh, origin: (Double, Double)) throws -> (Ring, String) {
    let ring = try ringMm(orderedRingM(try boxCornersM(mesh)), origin: origin)
    return (ring, ringToRectM(ring))
}

private func windowOpening(_ mesh: UsdaMesh, origin: (Double, Double)) throws -> Opening {
    let corners = try orderedRingM(try boxCornersM(mesh)).map {
        (max(0.0, $0.0 - origin.0), max(0.0, $0.1 - origin.1))
    }
    let ring = try ringMm(corners, origin: (0, 0))
    let verts = ring.vertices
    var edges: [(Double, Int, Int)] = []
    for index in verts.indices {
        let nxt = verts[(index + 1) % verts.count]
        let length = pow(Double(nxt.xMm - verts[index].xMm), 2) + pow(Double(nxt.yMm - verts[index].yMm), 2)
        let wall = min(verts[index].xMm + verts[index].yMm, nxt.xMm + nxt.yMm)
        edges.append((length, -wall, index))
    }
    let longI = edges.max { a, b in
        if a.0 != b.0 { return a.0 < b.0 }
        if a.1 != b.1 { return a.1 < b.1 }
        return a.2 < b.2
    }!.2
    return Opening(label: "okno", start: verts[longI], end: verts[(longI + 1) % verts.count])
}

private func openingToSegmentM(_ opening: Opening) -> String {
    String(
        format: "%.3f,%.3f,%.3f,%.3f",
        Double(opening.start.xMm) / 1000,
        Double(opening.start.yMm) / 1000,
        Double(opening.end.xMm) / 1000,
        Double(opening.end.yMm) / 1000
    )
}

private func doorThreshold(_ mesh: UsdaMesh, origin: (Double, Double)) throws -> Threshold {
    var ring = try ringMm(orderedRingM(try boxCornersM(mesh)), origin: origin)
    var (lengthMm, widthMm, longI) = rectAxes(ring)
    if widthMm < thresholdMm {
        ring = expandWidth(ring, longI: longI, widthMm: thresholdMm)
        widthMm = thresholdMm
    }
    return Threshold(label: "listwa progowa", lengthMm: lengthMm, widthMm: widthMm, geometry: ring)
}

private func rectAxes(_ ring: Ring) -> (Int, Int, Int) {
    let verts = ring.vertices
    var edges: [(Int, Int)] = []
    for index in verts.indices {
        let nxt = verts[(index + 1) % verts.count]
        let dx = Double(nxt.xMm - verts[index].xMm)
        let dy = Double(nxt.yMm - verts[index].yMm)
        edges.append((Int((dx * dx + dy * dy).squareRoot().rounded()), index))
    }
    let long = edges.max { $0.0 < $1.0 }!
    let short = edges.map(\.0).min()!
    return (long.0, short, long.1)
}

private func expandWidth(_ ring: Ring, longI: Int, widthMm: Int) -> Ring {
    let verts = ring.vertices
    let a = verts[longI]
    let b = verts[(longI + 1) % verts.count]
    let dx = Double(b.xMm - a.xMm)
    let dy = Double(b.yMm - a.yMm)
    let length = (dx * dx + dy * dy).squareRoot() == 0 ? 1.0 : (dx * dx + dy * dy).squareRoot()
    let nx = -dy / length
    let ny = dx / length
    let current = rectAxes(ring).1
    let extra = Double(widthMm - current) / 2
    let cx = Double(verts.map(\.xMm).reduce(0, +)) / Double(verts.count)
    let cy = Double(verts.map(\.yMm).reduce(0, +)) / Double(verts.count)
    let grown = verts.map { vertex -> Vertex in
        let side = (Double(vertex.xMm) - cx) * nx + (Double(vertex.yMm) - cy) * ny >= 0 ? 1.0 : -1.0
        return Vertex(
            Int((Double(vertex.xMm) + side * extra * nx).rounded()),
            Int((Double(vertex.yMm) + side * extra * ny).rounded())
        )
    }
    return try! Ring(grown)
}

private func ringMm(_ points: [(Double, Double)], origin: (Double, Double)) throws -> Ring {
    let verts = try points.map { point in
        Vertex(
            try metresToMmCoord(String(format: "%.6f", point.0 - origin.0)),
            try metresToMmCoord(String(format: "%.6f", point.1 - origin.1))
        )
    }
    var path = normalizeRing(verts)
    let start = path.indices.min { a, b in
        if path[a].xMm != path[b].xMm { return path[a].xMm < path[b].xMm }
        if path[a].yMm != path[b].yMm { return path[a].yMm < path[b].yMm }
        return a < b
    } ?? 0
    path = Array(path[start...]) + Array(path[..<start])
    return try Ring(path)
}

private func ringToVerticesM(_ ring: Ring) -> String {
    ring.vertices.map { String(format: "%.3f,%.3f", Double($0.xMm) / 1000, Double($0.yMm) / 1000) }
        .joined(separator: "\n")
}

private func ringToRectM(_ ring: Ring) -> String {
    let xs = ring.vertices.map(\.xMm)
    let ys = ring.vertices.map(\.yMm)
    let minX = xs.min() ?? 0
    let minY = ys.min() ?? 0
    let widthM = Double((xs.max() ?? 0) - minX) / 1000
    let heightM = Double((ys.max() ?? 0) - minY) / 1000
    return String(format: "%.3f,%.3f,%.3f,%.3f", Double(minX) / 1000, Double(minY) / 1000, widthM, heightM)
}
