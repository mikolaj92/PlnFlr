/// Shoelace area in mm². Matches pyclipper.Area for simple polygons.
public func areaMm2(_ vertices: [Vertex]) -> Int {
    guard vertices.count >= 3 else { return 0 }
    var sum = 0
    for i in vertices.indices {
        let j = (i + 1) % vertices.count
        sum += vertices[i].xMm * vertices[j].yMm
        sum -= vertices[j].xMm * vertices[i].yMm
    }
    return abs(sum) / 2
}
