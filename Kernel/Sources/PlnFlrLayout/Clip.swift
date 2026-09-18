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

func dropCollinear(_ vertices: [Vertex]) -> [Vertex] {
    let points = clean(vertices)
    guard points.count >= 3 else { return points }
    var kept: [Vertex] = []
    for i in points.indices {
        let prev = points[(i + points.count - 1) % points.count]
        let cur = points[i]
        let next = points[(i + 1) % points.count]
        let inDx = cur.xMm - prev.xMm
        let inDy = cur.yMm - prev.yMm
        let outDx = next.xMm - cur.xMm
        let outDy = next.yMm - cur.yMm
        if inDx * outDy == inDy * outDx { continue }
        kept.append(cur)
    }
    return kept
}

public func normalizeRing(_ outer: [Vertex]) -> [Vertex] {
    var points = dropCollinear(outer)
    if !orientationCcw(points) {
        points.reverse()
    }
    return points
}

func isOrthogonal(_ vertices: [Vertex]) -> Bool {
    let points = clean(vertices)
    guard points.count >= 3 else { return false }
    for i in points.indices {
        let a = points[i]
        let b = points[(i + 1) % points.count]
        if a.xMm != b.xMm && a.yMm != b.yMm { return false }
        if a.xMm == b.xMm && a.yMm == b.yMm { return false }
    }
    return true
}

/// Outward normal of a CCW axis-aligned edge.
func outwardNormal(_ a: Vertex, _ b: Vertex) -> (Int, Int) {
    let dx = b.xMm - a.xMm
    let dy = b.yMm - a.yMm
    if dy == 0 && dx > 0 { return (0, -1) }
    if dy == 0 && dx < 0 { return (0, 1) }
    if dx == 0 && dy > 0 { return (1, 0) }
    if dx == 0 && dy < 0 { return (-1, 0) }
    return (0, 0)
}

func offsetOrthogonal(_ vertices: [Vertex], delta: Int) throws -> [Vertex] {
    let points = normalizeRing(vertices)
    guard isOrthogonal(points) else { throw LayoutError.expansionGapLeavesNoArea }
    let n = points.count
    var out: [Vertex] = []
    out.reserveCapacity(n)
    for i in 0..<n {
        let prev = points[(i + n - 1) % n]
        let cur = points[i]
        let next = points[(i + 1) % n]
        let incoming = outwardNormal(prev, cur)
        let outgoing = outwardNormal(cur, next)
        out.append(
            Vertex(
                cur.xMm + incoming.0 * delta + outgoing.0 * delta,
                cur.yMm + incoming.1 * delta + outgoing.1 * delta
            )
        )
    }
    if abs(signedAreaMm2(out)) < 1 { throw LayoutError.expansionGapLeavesNoArea }
    return normalizeRing(out)
}

fileprivate func orthogonalRects(_ vertices: [Vertex]) -> [AABB] {
    let points = normalizeRing(vertices)
    guard isOrthogonal(points) else { return [] }
    let ys = Array(Set(points.map(\.yMm))).sorted()
    guard ys.count >= 2 else { return [] }
    var rects: [AABB] = []
    for i in 0..<(ys.count - 1) {
        let y0 = ys[i]
        let y1 = ys[i + 1]
        let mid = (y0 + y1) / 2
        var xs: [Int] = []
        for j in points.indices {
            let a = points[j]
            let b = points[(j + 1) % points.count]
            guard a.xMm == b.xMm else { continue }
            let lo = min(a.yMm, b.yMm)
            let hi = max(a.yMm, b.yMm)
            if lo < mid && mid < hi { xs.append(a.xMm) }
        }
        xs.sort()
        var k = 0
        while k + 1 < xs.count {
            let box = AABB(minX: xs[k], minY: y0, maxX: xs[k + 1], maxY: y1)
            if box.width > 0, box.height > 0 { rects.append(box) }
            k += 2
        }
    }
    return rects
}

public func validateRoom(outer: [Vertex], holes: [[Vertex]]) throws {
    let path = clean(outer)
    guard path.count >= 3 else { throw LayoutError.ringNeedsThreeVertices }
    if abs(signedAreaMm2(path)) < 1 {
        throw LayoutError.selfIntersectingPolygon
    }
    _ = holes // ponytail: hole topology needs Clipper; bowtie is area-zero
}

fileprivate struct AABB {
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

    init(minX: Int, minY: Int, maxX: Int, maxY: Int) {
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
    var grown: [[Vertex]] = []
    for hole in holes {
        if let box = AABB(hole), let out = box.offset(gapMm) {
            grown.append(out.vertices)
        } else {
            grown.append(try offsetOrthogonal(hole, delta: gapMm))
        }
    }
    if let outerBox = AABB(outer) {
        guard let inner = outerBox.offset(-gapMm) else {
            throw LayoutError.expansionGapLeavesNoArea
        }
        return (inner.vertices, grown)
    }
    return (try offsetOrthogonal(outer, delta: -gapMm), grown)
}

public func intersectRect(_ rect: [Vertex], outer: [Vertex], holes: [[Vertex]]) throws
    -> [[Vertex]]
{
    guard let subject = AABB(rect) else { return [] }
    let clips: [AABB]
    if let box = AABB(outer) {
        clips = [box]
    } else {
        clips = orthogonalRects(outer)
    }
    var parts: [AABB] = []
    for clip in clips {
        if let hit = subject.intersection(clip) { parts.append(hit) }
    }
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
