import PlnFlrLayout
import Testing

@Test func cwIsNormalizedToCcw() {
    let cw = [Vertex(0, 0), Vertex(0, 3000), Vertex(4000, 3000), Vertex(4000, 0)]
    #expect(orientationCcw(normalizeRing(cw)))
}

@Test func insetSquare() throws {
    let (inner, holes) = try inset(
        outer: [Vertex(0, 0), Vertex(4000, 0), Vertex(4000, 3000), Vertex(0, 3000)],
        holes: [],
        gapMm: 10
    )
    #expect(holes.isEmpty)
    let xs = inner.map(\.xMm)
    let ys = inner.map(\.yMm)
    #expect(xs.min() == 10 && xs.max() == 3990)
    #expect(ys.min() == 10 && ys.max() == 2990)
}

@Test func rectClipInsideIsIdentity() throws {
    let room = [Vertex(0, 0), Vertex(4000, 0), Vertex(4000, 3000), Vertex(0, 3000)]
    let r = [Vertex(100, 100), Vertex(200, 100), Vertex(200, 150), Vertex(100, 150)]
    let out = try intersectRect(r, outer: room, holes: [])
    #expect(out.count == 1)
}

@Test func rectOutsideEmpty() throws {
    let room = [Vertex(0, 0), Vertex(1000, 0), Vertex(1000, 1000), Vertex(0, 1000)]
    let r = [Vertex(2000, 2000), Vertex(2100, 2000), Vertex(2100, 2100), Vertex(2000, 2100)]
    #expect(try intersectRect(r, outer: room, holes: []).isEmpty)
}

@Test func selfIntersectingRejected() {
    let bowtie = [Vertex(0, 0), Vertex(100, 100), Vertex(100, 0), Vertex(0, 100)]
    #expect(throws: LayoutError.selfIntersectingPolygon) {
        try validateRoom(outer: bowtie, holes: [])
    }
}
