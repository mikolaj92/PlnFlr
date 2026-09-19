public func planToSvg(_ plan: LayoutPlan, maxPx: Int = 900) -> String {
    let bounds = bbox(plan.room)
    let width = max(bounds.maxX - bounds.minX, 1)
    let height = max(bounds.maxY - bounds.minY, 1)
    var evenodd = path(plan.room.outer)
    for hole in plan.room.holes { evenodd += " " + path(hole) }
    var gapPath = path(plan.room.outer) + " " + path(plan.inset.outer)
    for hole in plan.room.holes { gapPath += " " + path(hole) }
    for hole in plan.inset.holes { gapPath += " " + path(hole) }
    var pieces: [String] = []
    for piece in plan.pieces {
        let parity = piece.rowIndex % 2 == 0 ? "pln-row-even" : "pln-row-odd"
        var cls = "\(parity) pln-zone-\(piece.zoneIndex)"
        if piece.kind == .clip || piece.kind == .rip || piece.kind == .tileCut {
            cls += " pln-clip"
        }
        pieces.append(
            "<path class=\"\(cls)\" data-piece-id=\"\(piece.pieceId)\" data-zone=\"\(piece.zoneIndex)\" d=\"\(polyPath(piece.geometry))\" />"
        )
    }
    var labels: [String] = []
    var seen: Set<String> = []
    for piece in plan.pieces {
        let key = "\(piece.zoneIndex)-\(piece.rowIndex)"
        if seen.contains(key) { continue }
        seen.insert(key)
        let xs = piece.geometry.map(\.xMm)
        let ys = piece.geometry.map(\.yMm)
        let cx = ((xs.min() ?? 0) + (xs.max() ?? 0)) / 2
        let cy = ((ys.min() ?? 0) + (ys.max() ?? 0)) / 2
        labels.append(
            "<text class=\"pln-label\" x=\"\(cx)\" y=\"\(cy)\" text-anchor=\"middle\" dominant-baseline=\"middle\">\(piece.rowIndex + 1)</text>"
        )
    }
    var extras: [String] = []
    if let divider = plan.divider {
        extras.append(
            "<line class=\"pln-divider\" x1=\"\(divider.0.xMm)\" y1=\"\(divider.0.yMm)\" x2=\"\(divider.1.xMm)\" y2=\"\(divider.1.yMm)\" />"
        )
    }
    for strip in plan.thresholds {
        extras.append("<path class=\"pln-threshold\" d=\"\(path(strip.geometry))\" />")
    }
    for window in plan.windows {
        extras.append(
            "<line class=\"pln-window\" x1=\"\(window.start.xMm)\" y1=\"\(window.start.yMm)\" x2=\"\(window.end.xMm)\" y2=\"\(window.end.yMm)\" />"
        )
    }
    let body = [
        "<path class=\"pln-room\" fill-rule=\"evenodd\" d=\"\(evenodd)\" />",
        "<path class=\"pln-gap\" fill-rule=\"evenodd\" d=\"\(gapPath)\" />",
    ] + pieces + extras + labels
    return
        "<svg class=\"pln-preview\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"\(bounds.minX) \(bounds.minY) \(width) \(height)\" width=\"\(maxPx)\" role=\"img\" aria-label=\"Plan ułożenia podłogi\">\(body.joined())</svg>"
}

private func path(_ ring: Ring) -> String {
    polyPath(ring.vertices)
}

private func polyPath(_ points: [Vertex]) -> String {
    guard let start = points.first else { return "" }
    var parts = ["M \(start.xMm) \(start.yMm)"]
    for v in points.dropFirst() {
        parts.append("L \(v.xMm) \(v.yMm)")
    }
    parts.append("Z")
    return parts.joined(separator: " ")
}
