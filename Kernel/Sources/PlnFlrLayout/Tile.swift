public func layoutTiles(
    _ room: Room,
    _ spec: TileSpec,
    _ rules: LayoutRules,
    windows: [Opening] = []
) throws -> LayoutPlan {
    let gap = try resolveGapMm(room, rules)
    let inner = try insetRoom(room, gapMm: gap)
    let angle = ((rules.angleDeg % 360) + 360) % 360
    let origin = originOf(inner)
    let gridRoom = angle == 0 ? inner : try rotateRoom(inner, angleDeg: angle, origin: origin)
    var pieces = try layTiles(gridRoom, spec, rules)
    if angle != 0 {
        pieces = pieces.map { piece in
            var copy = piece
            copy.geometry = rotatePoints(piece.geometry, angleDeg: -angle, origin: origin)
            return copy
        }
    }
    let net = areaMm2(inner.outer.vertices)
        - inner.holes.reduce(0) { $0 + areaMm2($1.vertices) }
    let bom = makeBom(
        pieces: pieces.count,
        fullBoards: pieces.map(\.sourceBoard).max() ?? 0,
        boardsPerPack: spec.tilesPerPack,
        areaNetMm2: net,
        boardAreaMm2: spec.lengthMm * spec.widthMm,
        label: "Płytki",
        kind: .tile
    )
    let angleNote = angle == 0 ? "" : " Kąt \(angle)°."
    return LayoutPlan(
        angleDeg: angle,
        bom: bom,
        boms: [bom],
        direction: .alongX,
        divider: nil,
        gapMm: gap,
        inset: inner,
        pieces: pieces,
        rationalePl: "Siatka płytek wycentrowana na bbox, przycięta do obrysu.\(angleNote)",
        room: room,
        rowsInstructionPl: instructionsFor(pieces, gapMm: gap, hasHoles: !room.holes.isEmpty),
        splitAtMm: nil,
        splitAxis: nil,
        warnings: [],
        windows: windows
    )
}

private func layTiles(_ inner: Room, _ spec: TileSpec, _ rules: LayoutRules) throws -> [Piece] {
    let bounds = bbox(inner)
    let innerW = bounds.maxX - bounds.minX
    let innerH = bounds.maxY - bounds.minY
    let pitchX = spec.lengthMm + spec.groutMm
    let pitchY = spec.widthMm + spec.groutMm
    var cols = max(1, (innerW + spec.groutMm) / pitchX)
    var rows = max(1, (innerH + spec.groutMm) / pitchY)
    var usedW = cols * spec.lengthMm + (cols - 1) * spec.groutMm
    var usedH = rows * spec.widthMm + (rows - 1) * spec.groutMm
    var remX = innerW - usedW
    var remY = innerH - usedH
    if remX > 0, remX < rules.minTileCutMm {
        cols += 1
        usedW = cols * spec.lengthMm + (cols - 1) * spec.groutMm
        remX = innerW - usedW
    }
    if remY > 0, remY < rules.minTileCutMm {
        rows += 1
        usedH = rows * spec.widthMm + (rows - 1) * spec.groutMm
        remY = innerH - usedH
    }
    let originX = bounds.minX + remX / 2
    let originY = bounds.minY + remY / 2
    var pieces: [Piece] = []
    var board = 0
    var order = 0
    for row in 0..<rows {
        for col in 0..<cols {
            let x0 = originX + col * pitchX
            let y0 = originY + row * pitchY
            let x1 = x0 + spec.lengthMm
            let y1 = y0 + spec.widthMm
            let rect = [Vertex(x0, y0), Vertex(x1, y0), Vertex(x1, y1), Vertex(x0, y1)]
            let clipped = try intersectRect(
                rect,
                outer: inner.outer.vertices,
                holes: inner.holes.map(\.vertices)
            )
            guard !clipped.isEmpty else { continue }
            board += 1
            for poly in clipped {
                order += 1
                pieces.append(
                    Piece(
                        geometry: poly,
                        installOrder: order,
                        kind: poly.count == 4 ? .tileFull : .tileCut,
                        lengthMm: spec.lengthMm,
                        pieceId: "t\(row)-\(col)-\(order)",
                        rowIndex: row,
                        sourceBoard: board,
                        widthMm: spec.widthMm
                    )
                )
            }
        }
    }
    return pieces
}
