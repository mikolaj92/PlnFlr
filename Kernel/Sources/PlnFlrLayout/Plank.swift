func originOf(_ room: Room) -> Vertex {
    let bounds = bbox(room)
    return Vertex((bounds.minX + bounds.maxX) / 2, (bounds.minY + bounds.maxY) / 2)
}

func rotateRoom(_ room: Room, angleDeg: Int, origin: Vertex) throws -> Room {
    guard angleDeg % 360 != 0 else { return room }
    let outer = try Ring(rotatePoints(room.outer.vertices, angleDeg: angleDeg, origin: origin))
    let holes = try room.holes.map {
        try Ring(rotatePoints($0.vertices, angleDeg: angleDeg, origin: origin))
    }
    return Room(outer, holes: holes)
}

func direction(of room: Room, rules: LayoutRules, windows: [Opening]) -> Axis {
    if rules.direction == .alongX { return .alongX }
    if rules.direction == .alongY { return .alongY }
    if rules.direction == .intoWindow, let window = windows.max(by: {
        abs($0.end.xMm - $0.start.xMm) + abs($0.end.yMm - $0.start.yMm)
            < abs($1.end.xMm - $1.start.xMm) + abs($1.end.yMm - $1.start.yMm)
    }) {
        let alongWallX = abs(window.end.xMm - window.start.xMm)
            >= abs(window.end.yMm - window.start.yMm)
        return alongWallX ? .alongY : .alongX
    }
    let bounds = bbox(room)
    var alongLong = (bounds.maxX - bounds.minX) >= (bounds.maxY - bounds.minY)
    if rules.direction == .alongShort { alongLong.toggle() }
    return alongLong ? .alongX : .alongY
}

public func layoutPlanks(
    _ room: Room,
    _ spec: PlankSpec,
    _ rules: LayoutRules,
    windows: [Opening] = []
) throws -> LayoutPlan {
    let gap = try resolveGapMm(room, rules)
    let inner = try insetRoom(room, gapMm: gap)
    let angle = ((rules.angleDeg % 360) + 360) % 360
    let origin = originOf(inner)
    let gridRoom = angle == 0 ? inner : try rotateRoom(inner, angleDeg: angle, origin: origin)
    let axis = direction(of: gridRoom, rules: rules, windows: windows)
    let bounds = bbox(gridRoom)
    let span = max(bounds.maxX - bounds.minX, bounds.maxY - bounds.minY)
    var warnings: [Warning] = []
    if span > rules.intermediateJointMm {
        let metres = String(format: "%.3f", Double(span) / 1000).replacingOccurrences(
            of: ".",
            with: ","
        )
        warnings.append(
            Warning(
                code: "intermediate_joint",
                messagePl:
                    "Pomieszczenie ma \(metres) m w świetle po dylatacji. Rozważ przerwę dylatacyjną / profil co ok. 8 m."
            )
        )
    }
    let slots = try iterSlots(
        minX: bounds.minX,
        minY: bounds.minY,
        maxX: bounds.maxX,
        maxY: bounds.maxY,
        plankLengthMm: spec.lengthMm,
        plankWidthMm: spec.widthMm,
        minRowWidthMm: rules.minRowWidthMm,
        minEndMm: rules.minEndLengthMm,
        stagger: rules.stagger,
        direction: axis
    )
    let outerPath = gridRoom.outer.vertices
    let holePaths = gridRoom.holes.map(\.vertices)
    var pieces: [Piece] = []
    var board = 0
    var order = 0
    for slot in slots {
        let rect = [
            Vertex(slot.x0, slot.y0),
            Vertex(slot.x1, slot.y0),
            Vertex(slot.x1, slot.y1),
            Vertex(slot.x0, slot.y1),
        ]
        let clipped = try intersectRect(rect, outer: outerPath, holes: holePaths)
        guard !clipped.isEmpty else { continue }
        board += 1
        for poly in clipped {
            order += 1
            let kind: PieceKind = poly.count == 4 ? slot.kind : .clip
            let along = axis == .alongX ? slot.x1 - slot.x0 : slot.y1 - slot.y0
            let across = axis == .alongX ? slot.y1 - slot.y0 : slot.x1 - slot.x0
            var geometry = poly
            if angle != 0 {
                geometry = rotatePoints(poly, angleDeg: -angle, origin: origin)
            }
            pieces.append(
                Piece(
                    geometry: geometry,
                    installOrder: order,
                    kind: kind,
                    lengthMm: along,
                    pieceId: "r\(slot.rowIndex)-b\(board)-\(order)",
                    rowIndex: slot.rowIndex,
                    sourceBoard: board,
                    widthMm: across
                )
            )
        }
    }
    let net = areaMm2(inner.outer.vertices)
        - inner.holes.reduce(0) { $0 + areaMm2($1.vertices) }
    let bom = makeBom(
        pieces: pieces.count,
        fullBoards: pieces.map(\.sourceBoard).max() ?? 0,
        boardsPerPack: spec.boardsPerPack,
        areaNetMm2: net,
        boardAreaMm2: spec.lengthMm * spec.widthMm
    )
    let innerBounds = bbox(inner)
    let longerX = (innerBounds.maxX - innerBounds.minX) >= (innerBounds.maxY - innerBounds.minY)
    let axisWord: String
    if rules.direction == .intoWindow, !windows.isEmpty {
        axisWord = "prostopadle do ściany z oknem"
    } else {
        axisWord = axis == .alongX && longerX ? "dłuższego" : "wybranego"
    }
    let angleNote = angle == 0 ? "" : " Kąt \(angle)°."
    let rationale: String
    if rules.direction == .intoWindow, !windows.isEmpty {
        rationale =
            "Deski prostopadle do okna (\(axisWord)). Dylatacja \(gap) mm. Siatka na bbox, przycięcie do obrysu.\(angleNote)"
    } else {
        rationale =
            "Kierunek \(axis.rawValue.replacingOccurrences(of: "_", with: " ")) — deski wzdłuż \(axisWord) boku. Dylatacja \(gap) mm. Siatka na bbox, przycięcie do obrysu.\(angleNote)"
    }
    return LayoutPlan(
        bom: bom,
        direction: axis,
        gapMm: gap,
        inset: inner,
        pieces: pieces,
        rationalePl: rationale,
        room: room,
        rowsInstructionPl: instructionsFor(pieces, gapMm: gap, hasHoles: !room.holes.isEmpty),
        warnings: warnings,
        windows: windows
    )
}
