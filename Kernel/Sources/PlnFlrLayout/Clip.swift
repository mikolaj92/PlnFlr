/// Axis-aligned clip and inset. Matches pyclipper goldens on rectangles.
/// Arbitrary polygons need Clipper; add it when a non-rect golden fails.

func clean(_ path: [Vertex]) -> [Vertex] {
    var points = path
    if points.count >= 2, points.first == points.last {
        points.removeLast()
    }
    return points
}

func signedAreaMm2(_ vertices: [Vertex]) -> Int {
    let points = clean(vertices)
    guard points.count >= 3 else { return 0 }
    var sum = 0
    for i in points.indices {
        let j = (i + 1) % points.count
        sum += points[i].xMm * points[j].yMm
        sum -= points[j].xMm * points[i].yMm
    }
    return sum / 2
}

public func orientationCcw(_ outer: [Vertex]) -> Bool {
    signedAreaMm2(outer) > 0
}

public func normalizeRing(_ outer: [Vertex]) -> [Vertex] {
    var points = clean(outer)
    if !orientationCcw(points) {
        points.reverse()
    }
    return points
}

public func validateRoom(outer: [Vertex], holes: [[Vertex]]) throws {
    let path = clean(outer)
    guard path.count >= 3 else { throw LayoutError.ringNeedsThreeVertices }
    if abs(signedAreaMm2(path)) < 1 {
        throw LayoutError.selfIntersectingPolygon
    }
    _ = holes // ponytail: hole topology needs Clipper; bowtie is area-zero
}

private struct AABB {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int

    var width: Int { maxX - minX }
    var height: Int { maxY - minY }

    init?(_ vertices: [Vertex]) {
        let points = clean(vertices)
        let xs = Set(points.map(\.xMm))
        let ys = Set(points.map(\.yMm))
        guard points.count == 4, xs.count == 2, ys.count == 2 else { return nil }
        minX = xs.min()!
        minY = ys.min()!
        maxX = xs.max()!
        maxY = ys.max()!
        guard width > 0, height > 0 else { return nil }
    }

    func offset(_ delta: Int) -> AABB? {
        let out = AABB(
            minX: minX - delta,
            minY: minY - delta,
            maxX: maxX + delta,
            maxY: maxY + delta
        )
        guard out.width > 0, out.height > 0 else { return nil }
        return out
    }

    func intersection(_ other: AABB) -> AABB? {
        let x0 = max(minX, other.minX)
        let y0 = max(minY, other.minY)
        let x1 = min(maxX, other.maxX)
        let y1 = min(maxY, other.maxY)
        guard x1 > x0, y1 > y0 else { return nil }
        return AABB(minX: x0, minY: y0, maxX: x1, maxY: y1)
    }

    /// Difference vs an axis-aligned hole. Covers a board split by a fireplace.
    func subtracting(_ hole: AABB) -> [AABB] {
        guard let hit = intersection(hole) else { return [self] }
        if hit.minX <= minX, hit.minY <= minY, hit.maxX >= maxX, hit.maxY >= maxY {
            return []
        }
        var parts: [AABB] = []
        if hit.minX > minX {
            parts.append(AABB(minX: minX, minY: minY, maxX: hit.minX, maxY: maxY))
        }
        if hit.maxX < maxX {
            parts.append(AABB(minX: hit.maxX, minY: minY, maxX: maxX, maxY: maxY))
        }
        if hit.minY > minY {
            parts.append(AABB(minX: hit.minX, minY: minY, maxX: hit.maxX, maxY: hit.minY))
        }
        if hit.maxY < maxY {
            parts.append(AABB(minX: hit.minX, minY: hit.maxY, maxX: hit.maxX, maxY: maxY))
        }
        return parts
    }

    var vertices: [Vertex] {
        [Vertex(minX, minY), Vertex(maxX, minY), Vertex(maxX, maxY), Vertex(minX, maxY)]
    }

    private init(minX: Int, minY: Int, maxX: Int, maxY: Int) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }
}

public func inset(outer: [Vertex], holes: [[Vertex]], gapMm: Int) throws -> (
    [Vertex], [[Vertex]]
) {
    guard gapMm >= 0 else { throw LayoutError.expansionMustBeNonNegative }
    if gapMm == 0 {
        return (normalizeRing(outer), holes.map(normalizeRing))
    }
    guard let outerBox = AABB(outer), let inner = outerBox.offset(-gapMm) else {
        throw LayoutError.expansionGapLeavesNoArea
    }
    var grown: [[Vertex]] = []
    for hole in holes {
        if let box = AABB(hole), let out = box.offset(gapMm) {
            grown.append(out.vertices)
        }
    }
    return (inner.vertices, grown)
}

public func intersectRect(_ rect: [Vertex], outer: [Vertex], holes: [[Vertex]]) throws
    -> [[Vertex]]
{
    guard let subject = AABB(rect), let clip = AABB(outer) else { return [] }
    guard let clipped = subject.intersection(clip) else { return [] }
    var parts = [clipped]
    for hole in holes {
        guard let cut = AABB(hole) else { continue }
        parts = parts.flatMap { $0.subtracting(cut) }
    }
    return parts.map(\.vertices)
}

public func insetRoom(_ room: Room, gapMm: Int) throws -> Room {
    let (inner, holes) = try inset(
        outer: room.outer.vertices,
        holes: room.holes.map(\.vertices),
        gapMm: gapMm
    )
    return Room(try Ring(inner), holes: try holes.map { try Ring($0) })
}
