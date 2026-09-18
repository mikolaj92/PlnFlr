import PlnFlrLayout
import Testing

@Test func explicitGapOnRectangle() throws {
    let room = try rectangle(widthMm: 4000, heightMm: 3000)
    let gap = try resolveGapMm(room, LayoutRules(expansionMm: 12))
    let inner = try insetRoom(room, gapMm: gap)
    #expect(gap == 12)
    #expect(areaMm2(inner.outer.vertices) == 3976 * 2976)
}

@Test func autoGapUsesLongestBboxSide() throws {
    let room = try rectangle(widthMm: 8000, heightMm: 3000)
    #expect(try resolveGapMm(room, LayoutRules()) == 12)
}

@Test func autoGapRespectsMinimum() throws {
    let room = try rectangle(widthMm: 4000, heightMm: 3000)
    #expect(try resolveGapMm(room, LayoutRules()) == 10)
}

@Test func holeGrowsByGap() throws {
    let outer = try rectangle(widthMm: 4000, heightMm: 4000).outer
    let hole = try Ring([
        Vertex(1500, 1500),
        Vertex(2500, 1500),
        Vertex(2500, 2500),
        Vertex(1500, 2500),
    ])
    let inner = try insetRoom(Room(outer, holes: [hole]), gapMm: 10)
    #expect(inner.holes.count == 1)
    let xs = inner.holes[0].vertices.map(\.xMm)
    let ys = inner.holes[0].vertices.map(\.yMm)
    #expect(xs.min() == 1490 && xs.max() == 2510)
    #expect(ys.min() == 1490 && ys.max() == 2510)
}
