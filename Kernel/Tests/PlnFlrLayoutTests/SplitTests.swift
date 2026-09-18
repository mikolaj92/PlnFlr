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
