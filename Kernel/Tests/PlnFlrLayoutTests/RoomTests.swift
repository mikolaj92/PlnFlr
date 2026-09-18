import PlnFlrLayout
import Testing

@Test func ringRequiresAtLeastThreeVertices() {
    #expect(throws: LayoutError.ringNeedsThreeVertices) {
        try Ring([Vertex(0, 0), Vertex(1, 0)])
    }
}

@Test func rectangleHasFourVerticesAndExpectedSize() throws {
    let room = try rectangle(widthMm: 4000, heightMm: 3000)
    #expect(room.outer.vertices.count == 4)
    #expect(room.holes.isEmpty)
    let xs = room.outer.vertices.map(\.xMm)
    let ys = room.outer.vertices.map(\.yMm)
    #expect(xs.min() == 0 && xs.max() == 4000)
    #expect(ys.min() == 0 && ys.max() == 3000)
}

@Test func lShapeHasSixVertices() throws {
    let room = try lShape(spanXMm: 6000, spanYMm: 4000, cutoutXMm: 2500, cutoutYMm: 2000)
    #expect(room.outer.vertices.count == 6)
    #expect(room.holes.isEmpty)
}

@Test func roomAcceptsHoles() throws {
    let outer = try rectangle(widthMm: 4000, heightMm: 3000).outer
    let hole = try Ring([
        Vertex(1500, 1000),
        Vertex(2500, 1000),
        Vertex(2500, 2000),
        Vertex(1500, 2000),
    ])
    let room = Room(outer, holes: [hole])
    #expect(room.holes.count == 1)
}

@Test func squareArea() throws {
    let room = try rectangle(widthMm: 4000, heightMm: 3000)
    #expect(areaMm2(room.outer.vertices) == 4000 * 3000)
}
