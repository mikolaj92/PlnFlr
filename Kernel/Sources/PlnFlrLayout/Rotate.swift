/// Integer-mm rotation. Multiples of 90° stay exact.

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public func rotatePoints(
    _ points: [Vertex],
    angleDeg: Int,
    origin: Vertex = Vertex(0, 0)
) -> [Vertex] {
    let angle = ((angleDeg % 360) + 360) % 360
    let ox = origin.xMm
    let oy = origin.yMm
    let exact: (Int, Int)? =
        switch angle {
        case 0: (1, 0)
        case 90: (0, 1)
        case 180: (-1, 0)
        case 270: (0, -1)
        default: nil
        }
    if let (cosine, sine) = exact {
        return points.map { p in
            Vertex(
                ox + (p.xMm - ox) * cosine - (p.yMm - oy) * sine,
                oy + (p.xMm - ox) * sine + (p.yMm - oy) * cosine
            )
        }
    }
    let rad = Double(angle) * .pi / 180
    let cosine = cos(rad)
    let sine = sin(rad)
    return points.map { p in
        let dx = Double(p.xMm - ox)
        let dy = Double(p.yMm - oy)
        return Vertex(
            Int((Double(ox) + dx * cosine - dy * sine).rounded()),
            Int((Double(oy) + dx * sine + dy * cosine).rounded())
        )
    }
}
