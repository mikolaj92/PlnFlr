import PlnFlrLayout
import Testing

@Test func rotate90IsExact() {
    let points = [Vertex(0, 0), Vertex(1000, 0), Vertex(1000, 400), Vertex(0, 400)]
    let rotated = rotatePoints(points, angleDeg: 90, origin: Vertex(0, 0))
    #expect(rotated == [Vertex(0, 0), Vertex(0, 1000), Vertex(-400, 1000), Vertex(-400, 0)])
}

@Test func rotate0IsIdentity() {
    let points = [Vertex(10, 20), Vertex(30, 40)]
    #expect(rotatePoints(points, angleDeg: 0, origin: Vertex(0, 0)) == points)
}
