private let pad = 100

public func splitRoom(_ room: Room, axis: SplitAxis, atMm: Int) throws -> (Room?, Room?) {
    let bounds = bbox(room)
    let firstClip: [Vertex]
    let secondClip: [Vertex]
    if axis == .x {
        firstClip = [
            Vertex(bounds.minX - pad, bounds.minY - pad),
            Vertex(atMm, bounds.minY - pad),
            Vertex(atMm, bounds.maxY + pad),
            Vertex(bounds.minX - pad, bounds.maxY + pad),
        ]
        secondClip = [
            Vertex(atMm, bounds.minY - pad),
            Vertex(bounds.maxX + pad, bounds.minY - pad),
            Vertex(bounds.maxX + pad, bounds.maxY + pad),
            Vertex(atMm, bounds.maxY + pad),
        ]
    } else {
        firstClip = [
            Vertex(bounds.minX - pad, bounds.minY - pad),
            Vertex(bounds.maxX + pad, bounds.minY - pad),
            Vertex(bounds.maxX + pad, atMm),
            Vertex(bounds.minX - pad, atMm),
        ]
        secondClip = [
            Vertex(bounds.minX - pad, atMm),
            Vertex(bounds.maxX + pad, atMm),
            Vertex(bounds.maxX + pad, bounds.maxY + pad),
            Vertex(bounds.minX - pad, bounds.maxY + pad),
        ]
    }
    return (try clipRoom(room, firstClip), try clipRoom(room, secondClip))
}

private func clipRoom(_ room: Room, _ clip: [Vertex]) throws -> Room? {
    let outers = try intersectRect(room.outer.vertices, outer: clip, holes: [])
    guard let outer = outers.max(by: { areaMm2($0) < areaMm2($1) }), outer.count >= 3 else {
        return nil
    }
    var holes: [Ring] = []
    for hole in room.holes {
        for poly in try intersectRect(hole.vertices, outer: clip, holes: []) where poly.count >= 3 {
            holes.append(try Ring(poly))
        }
    }
    return Room(try Ring(outer), holes: holes)
}
