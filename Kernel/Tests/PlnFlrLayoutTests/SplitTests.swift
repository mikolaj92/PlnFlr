import PlnFlrLayout
import Testing

@Test func splitRectangleOnXKeepsArea() throws {
    let room = try rectangle(widthMm: 4000, heightMm: 3000)
    let (left, right) = try splitRoom(room, axis: .x, atMm: 1500)
    let leftRoom = try #require(left)
    let rightRoom = try #require(right)
    #expect(areaMm2(leftRoom.outer.vertices) == 1500 * 3000)
    #expect(areaMm2(rightRoom.outer.vertices) == 2500 * 3000)
}

@Test func joinAdjacentRectanglesRestoresArea() throws {
    let left = try rectangle(widthMm: 1500, heightMm: 3000)
    let right = try Room(
        try Ring([
            Vertex(1500, 0),
            Vertex(4000, 0),
            Vertex(4000, 3000),
            Vertex(1500, 3000),
        ])
    )
    let joined = try joinRooms(left, right)
    #expect(areaMm2(joined.outer.vertices) == 4000 * 3000)
    let xs = joined.outer.vertices.map(\.xMm)
    let ys = joined.outer.vertices.map(\.yMm)
    #expect(xs.min() == 0 && xs.max() == 4000)
    #expect(ys.min() == 0 && ys.max() == 3000)
}
