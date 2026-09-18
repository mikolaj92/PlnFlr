/// Convex clip of a subject polygon against a convex clip polygon (integer mm).

func intersectConvex(_ subject: [Vertex], _ clip: [Vertex]) -> [Vertex] {
    var output = clean(subject)
    let clipRing = normalizeRing(clip)
    guard clipRing.count >= 3, output.count >= 3 else { return [] }
    for i in clipRing.indices {
        let a = clipRing[i]
        let b = clipRing[(i + 1) % clipRing.count]
        let input = output
        output = []
        guard let last = input.last else { return [] }
        var s = last
        for e in input {
            let eIn = isInside(e, a, b)
            let sIn = isInside(s, a, b)
            if eIn {
                if !sIn { output.append(intersection(s, e, a, b)) }
                output.append(e)
            } else if sIn {
                output.append(intersection(s, e, a, b))
            }
            s = e
        }
    }
    return output
}

private func isInside(_ p: Vertex, _ a: Vertex, _ b: Vertex) -> Bool {
    (b.xMm - a.xMm) * (p.yMm - a.yMm) - (b.yMm - a.yMm) * (p.xMm - a.xMm) >= 0
}

private func intersection(_ s: Vertex, _ e: Vertex, _ a: Vertex, _ b: Vertex) -> Vertex {
    let x1 = Double(s.xMm), y1 = Double(s.yMm)
    let x2 = Double(e.xMm), y2 = Double(e.yMm)
    let x3 = Double(a.xMm), y3 = Double(a.yMm)
    let x4 = Double(b.xMm), y4 = Double(b.yMm)
    let den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    if den == 0 { return e }
    let t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
    return Vertex(
        Int((x1 + t * (x2 - x1)).rounded()),
        Int((y1 + t * (y2 - y1)).rounded())
    )
}
