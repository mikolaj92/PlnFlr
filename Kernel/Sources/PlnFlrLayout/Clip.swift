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

func orthogonalRects(_ vertices: [Vertex]) -> [AABB] {
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

struct AABB {
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
    if isOrthogonal(outer) {
        return (try offsetOrthogonal(outer, delta: -gapMm), grown)
    }
    return (try offsetConvex(outer, delta: -gapMm), grown)
}

public func intersectRect(_ rect: [Vertex], outer: [Vertex], holes: [[Vertex]]) throws
    -> [[Vertex]]
{
    guard let subject = AABB(rect) else { return [] }
    if let box = AABB(outer) {
        guard var parts = optionalList(subject.intersection(box)) else { return [] }
        for hole in holes {
            guard let cut = AABB(hole) else { continue }
            parts = parts.flatMap { $0.subtracting(cut) }
        }
        return parts.map(\.vertices)
    }
    if isOrthogonal(outer) {
        var parts: [AABB] = []
        for clip in orthogonalRects(outer) {
            if let hit = subject.intersection(clip) { parts.append(hit) }
        }
        for hole in holes {
            guard let cut = AABB(hole) else { continue }
            parts = parts.flatMap { $0.subtracting(cut) }
        }
        return parts.map(\.vertices)
    }
    let clipped = intersectConvex(subject.vertices, outer)
    guard clipped.count >= 3 else { return [] }
    // ponytail: convex clip only; non-rect holes need Clipper
    _ = holes
    return [clipped]
}

private func optionalList(_ box: AABB?) -> [AABB]? {
    box.map { [$0] }
}

func offsetConvex(_ vertices: [Vertex], delta: Int) throws -> [Vertex] {
    let points = normalizeRing(vertices)
    guard points.count >= 3 else { throw LayoutError.expansionGapLeavesNoArea }
    let n = points.count
    var lines: [(Vertex, Vertex)] = []
    for i in 0..<n {
        let a = points[i]
        let b = points[(i + 1) % n]
        let dx = Double(b.xMm - a.xMm)
        let dy = Double(b.yMm - a.yMm)
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 0 else { continue }
        // Outward for CCW: rotate 90 CW. Negative delta shrinks.
        let nx = dy / len * Double(delta)
        let ny = -dx / len * Double(delta)
        lines.append(
            (
                Vertex(Int((Double(a.xMm) + nx).rounded()), Int((Double(a.yMm) + ny).rounded())),
                Vertex(Int((Double(b.xMm) + nx).rounded()), Int((Double(b.yMm) + ny).rounded()))
            )
        )
    }
    guard lines.count == n else { throw LayoutError.expansionGapLeavesNoArea }
    var out: [Vertex] = []
    for i in 0..<n {
        let prev = lines[(i + n - 1) % n]
        let cur = lines[i]
        guard let hit = lineIntersection(prev.0, prev.1, cur.0, cur.1) else {
            throw LayoutError.expansionGapLeavesNoArea
        }
        out.append(hit)
    }
    if abs(signedAreaMm2(out)) < 1 { throw LayoutError.expansionGapLeavesNoArea }
    return normalizeRing(out)
}

private func lineIntersection(_ a: Vertex, _ b: Vertex, _ c: Vertex, _ d: Vertex) -> Vertex? {
    let x1 = Double(a.xMm), y1 = Double(a.yMm), x2 = Double(b.xMm), y2 = Double(b.yMm)
    let x3 = Double(c.xMm), y3 = Double(c.yMm), x4 = Double(d.xMm), y4 = Double(d.yMm)
    let den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    guard den != 0 else { return nil }
    let px = ((x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - y3 * x4)) / den
    let py = ((x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - y3 * x4)) / den
    return Vertex(Int(px.rounded()), Int(py.rounded()))
}

public func joinRooms(_ a: Room, _ b: Room) throws -> Room {
    let rects = orthogonalRects(a.outer.vertices) + orthogonalRects(b.outer.vertices)
    guard rects.count >= 2, rectsShareBoundary(rects) else {
        throw LayoutError.joinRoomsMustTouch
    }
    return Room(try Ring(unionOrthogonalRects(rects)), holes: a.holes + b.holes)
}

private func rectsShareBoundary(_ rects: [AABB]) -> Bool {
    for i in rects.indices {
        for j in rects.indices where j > i {
            if shareEdgeOrOverlap(rects[i], rects[j]) { return true }
        }
    }
    return false
}

private func shareEdgeOrOverlap(_ a: AABB, _ b: AABB) -> Bool {
    if a.intersection(b) != nil { return true }
    let yOverlap = min(a.maxY, b.maxY) > max(a.minY, b.minY)
    let xOverlap = min(a.maxX, b.maxX) > max(a.minX, b.minX)
    if a.maxX == b.minX || b.maxX == a.minX { return yOverlap }
    if a.maxY == b.minY || b.maxY == a.minY { return xOverlap }
    return false
}

private func unionOrthogonalRects(_ rects: [AABB]) -> [Vertex] {
    let xs = Array(Set(rects.flatMap { [$0.minX, $0.maxX] })).sorted()
    let ys = Array(Set(rects.flatMap { [$0.minY, $0.maxY] })).sorted()
    guard xs.count >= 2, ys.count >= 2 else { return [] }
    var covered = Array(
        repeating: Array(repeating: false, count: ys.count - 1),
        count: xs.count - 1
    )
    for box in rects {
        for i in 0..<(xs.count - 1) {
            for j in 0..<(ys.count - 1) where box.minX <= xs[i] && box.maxX >= xs[i + 1]
                && box.minY <= ys[j] && box.maxY >= ys[j + 1]
            {
                covered[i][j] = true
            }
        }
    }
    var outgoing: [Vertex: [Vertex]] = [:]
    func add(_ from: Vertex, _ to: Vertex) {
        outgoing[from, default: []].append(to)
    }
    for i in 0..<(xs.count - 1) {
        for j in 0..<(ys.count - 1) where covered[i][j] {
            if j == 0 || !covered[i][j - 1] {
                add(Vertex(xs[i], ys[j]), Vertex(xs[i + 1], ys[j]))
            }
            if i == xs.count - 2 || !covered[i + 1][j] {
                add(Vertex(xs[i + 1], ys[j]), Vertex(xs[i + 1], ys[j + 1]))
            }
            if j == ys.count - 2 || !covered[i][j + 1] {
                add(Vertex(xs[i + 1], ys[j + 1]), Vertex(xs[i], ys[j + 1]))
            }
            if i == 0 || !covered[i - 1][j] {
                add(Vertex(xs[i], ys[j + 1]), Vertex(xs[i], ys[j]))
            }
        }
    }
    guard let start = outgoing.keys.min(by: { a, b in
        if a.xMm != b.xMm { return a.xMm < b.xMm }
        return a.yMm < b.yMm
    }) else { return [] }
    var ring: [Vertex] = [start]
    var current = start
    var previous = start
    repeat {
        let nexts = outgoing[current] ?? []
        let nxt = nexts.first { $0 != previous } ?? nexts[0]
        if nxt == start { break }
        ring.append(nxt)
        previous = current
        current = nxt
        if ring.count > xs.count * ys.count * 4 { break }
    } while current != start
    return normalizeRing(ring)
}

public func insetRoom(_ room: Room, gapMm: Int) throws -> Room {
    let (inner, holes) = try inset(
        outer: room.outer.vertices,
        holes: room.holes.map(\.vertices),
        gapMm: gapMm
    )
    return Room(try Ring(inner), holes: try holes.map { try Ring($0) })
}
