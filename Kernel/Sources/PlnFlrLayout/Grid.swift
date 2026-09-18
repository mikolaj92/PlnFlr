struct Slot: Equatable {
    var kind: PieceKind
    var rowIndex: Int
    var x0: Int
    var x1: Int
    var y0: Int
    var y1: Int
}

public func splitRows(innerMm: Int, plankWidthMm: Int, minRowWidthMm: Int) throws -> [Int] {
    guard innerMm > 0, plankWidthMm > 0 else { throw LayoutError.spansMustBePositive }
    let n = innerMm / plankWidthMm
    let rem = innerMm % plankWidthMm
    if n == 0 { return [innerMm] }
    if rem == 0 { return Array(repeating: plankWidthMm, count: n) }
    if rem < minRowWidthMm {
        let extra = plankWidthMm + rem
        let first = extra / 2
        let last = extra - first
        let middle = n - 1
        if middle < 0 {
            return last == 0 ? [first] : [first, last]
        }
        return [first] + Array(repeating: plankWidthMm, count: middle) + [last]
    }
    return Array(repeating: plankWidthMm, count: n) + [rem]
}

func rowLengths(innerMm: Int, plankLengthMm: Int, startCutMm: Int, minEndMm: Int) -> [Int] {
    var start = startCutMm
    if start <= 0 || start >= plankLengthMm {
        start = plankLengthMm
    }
    var remaining = innerMm - start
    if remaining < 0 { return [innerMm] }
    var lengths = [start]
    while remaining > 0 {
        if remaining >= plankLengthMm {
            lengths.append(plankLengthMm)
            remaining -= plankLengthMm
        } else {
            lengths.append(remaining)
            remaining = 0
        }
    }
    if lengths.count >= 2, lengths[lengths.count - 1] < minEndMm {
        let need = minEndMm - lengths[lengths.count - 1]
        if lengths[0] - need >= minEndMm {
            lengths[0] -= need
            lengths[lengths.count - 1] += need
        } else {
            let extra = lengths[0] + lengths[lengths.count - 1]
            lengths[0] = extra / 2
            lengths[lengths.count - 1] = extra - lengths[0]
        }
    }
    return lengths
}

func iterSlots(
    minX: Int,
    minY: Int,
    maxX: Int,
    maxY: Int,
    plankLengthMm: Int,
    plankWidthMm: Int,
    minRowWidthMm: Int,
    minEndMm: Int,
    stagger: Stagger,
    direction: Axis
) throws -> [Slot] {
    let along = direction == .alongX ? maxX - minX : maxY - minY
    let across = direction == .alongX ? maxY - minY : maxX - minX
    let rows = try splitRows(innerMm: across, plankWidthMm: plankWidthMm, minRowWidthMm: minRowWidthMm)
    let step = stagger == .third ? plankLengthMm / 3 : plankLengthMm / 2
    var slots: [Slot] = []
    var offset = direction == .alongX ? minY : minX
    for (rowIndex, width) in rows.enumerated() {
        var startCut = plankLengthMm
        if rowIndex != 0 {
            startCut = plankLengthMm - ((rowIndex * step) % plankLengthMm)
            if startCut < minEndMm { startCut = minEndMm }
            if startCut > plankLengthMm - minEndMm { startCut = plankLengthMm }
        }
        let lengths = rowLengths(
            innerMm: along,
            plankLengthMm: plankLengthMm,
            startCutMm: startCut,
            minEndMm: minEndMm
        )
        var cursor = direction == .alongX ? minX : minY
        for (col, length) in lengths.enumerated() {
            var kind: PieceKind
            if col == 0, length != plankLengthMm {
                kind = .startCut
            } else if col == lengths.count - 1, length != plankLengthMm {
                kind = .endCut
            } else {
                kind = .full
            }
            if width != plankWidthMm { kind = .rip }
            if direction == .alongX {
                slots.append(
                    Slot(
                        kind: kind,
                        rowIndex: rowIndex,
                        x0: cursor,
                        x1: cursor + length,
                        y0: offset,
                        y1: offset + width
                    )
                )
            } else {
                slots.append(
                    Slot(
                        kind: kind,
                        rowIndex: rowIndex,
                        x0: offset,
                        x1: offset + width,
                        y0: cursor,
                        y1: cursor + length
                    )
                )
            }
            cursor += length
        }
        offset += width
    }
    return slots
}
