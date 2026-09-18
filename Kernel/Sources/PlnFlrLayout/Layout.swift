public func layoutFloor(
    _ room: Room,
    zones: [Zone],
    rules: LayoutRules,
    splitAxis: SplitAxis? = nil,
    splitAtMm: Int? = nil,
    windows: [Opening] = []
) throws -> LayoutPlan {
    guard !zones.isEmpty else { throw LayoutError.needAtLeastOneZone }
    try validateRoom(outer: room.outer.vertices, holes: room.holes.map(\.vertices))
    if splitAxis == nil || zones.count == 1 {
        return try stamp(layoutZone(room, zones[0], rules, windows: windows), 0)
    }
    let bounds = bbox(room)
    let at = splitAtMm ?? (splitAxis == .x
        ? (bounds.minX + bounds.maxX) / 2
        : (bounds.minY + bounds.maxY) / 2)
    let (first, second) = try splitRoom(room, axis: splitAxis!, atMm: at)
    var plans: [LayoutPlan] = []
    if let first {
        plans.append(try stamp(layoutZone(first, zones[0], rules, windows: windows), 0))
    }
    if let second, zones.count > 1 {
        plans.append(try stamp(layoutZone(second, zones[1], rules, windows: windows), 1))
    }
    guard !plans.isEmpty else { throw LayoutError.splitLeavesNoArea }
    var merged = merge(room, plans, rules, splitAxis: splitAxis!, splitAtMm: at)
    merged.windows = windows
    return merged
}

private func layoutZone(
    _ room: Room,
    _ zone: Zone,
    _ rules: LayoutRules,
    windows: [Opening]
) throws -> LayoutPlan {
    var zoneRules = rules
    if let angle = zone.angleDeg { zoneRules.angleDeg = angle }
    if zone.kind == .tile {
        guard let tile = zone.tile else { throw LayoutError.tileZoneMissingSpec }
        var plan = try layoutTiles(room, tile, zoneRules, windows: windows)
        plan.bom.label = zone.label ?? "Płytki"
        plan.bom.kind = .tile
        plan.boms = [plan.bom]
        return plan
    }
    guard let plank = zone.plank else { throw LayoutError.plankZoneMissingSpec }
    var plan = try layoutPlanks(room, plank, zoneRules, windows: windows)
    plan.bom.label = zone.label ?? "Panele"
    plan.bom.kind = .plank
    plan.boms = [plan.bom]
    return plan
}

private func stamp(_ plan: LayoutPlan, _ zoneIndex: Int) -> LayoutPlan {
    var copy = plan
    copy.pieces = plan.pieces.map { piece in
        var p = piece
        p.zoneIndex = zoneIndex
        p.pieceId = "z\(zoneIndex)-\(piece.pieceId)"
        return p
    }
    return copy
}

private func merge(
    _ room: Room,
    _ plans: [LayoutPlan],
    _ rules: LayoutRules,
    splitAxis: SplitAxis,
    splitAtMm: Int
) -> LayoutPlan {
    let pieces = plans.flatMap(\.pieces)
    let boms = plans.map(\.bom)
    let warnings = plans.flatMap(\.warnings)
    let net = boms.reduce(0) { $0 + $1.areaNetMm2 }
    let bought = boms.reduce(0) { $0 + $1.areaBoughtMm2 }
    let mixed = BillOfMaterials(
        areaBoughtMm2: bought,
        areaNetMm2: net,
        fullBoards: boms.reduce(0) { $0 + $1.fullBoards },
        kind: .mixed,
        label: "Razem",
        packs: nil,
        pieces: boms.reduce(0) { $0 + $1.pieces },
        wastePct: wastePct(areaBoughtMm2: bought, areaNetMm2: net)
    )
    let gap = plans[0].gapMm
    let bounds = bbox(room)
    let divider: (Vertex, Vertex)
    let splitWord: String
    if splitAxis == .x {
        divider = (Vertex(splitAtMm, bounds.minY), Vertex(splitAtMm, bounds.maxY))
        splitWord = "pionową"
    } else {
        divider = (Vertex(bounds.minX, splitAtMm), Vertex(bounds.maxX, splitAtMm))
        splitWord = "poziomą"
    }
    let labels = boms.map { $0.label.isEmpty ? $0.kind.rawValue : $0.label }.joined(separator: " / ")
    let angle = rules.angleDeg
    let angleNote = angle == 0 ? "" : " Kąt \(angle)°."
    var lines = ["Dylatacja \(gap) mm wokół obrysu i na podziałce."]
    for plan in plans {
        let label = plan.bom.label.isEmpty ? "Strefa" : plan.bom.label
        lines.append("\(label):")
        lines.append(contentsOf: plan.rowsInstructionPl.filter { !$0.hasPrefix("Dylatacja") })
    }
    return LayoutPlan(
        angleDeg: angle,
        bom: mixed,
        boms: boms,
        direction: plans[0].direction,
        divider: divider,
        gapMm: gap,
        inset: plans[0].inset,
        pieces: pieces,
        rationalePl:
            "Podziałka \(splitWord) na \(splitAtMm) mm: \(labels). Dylatacja \(gap) mm także na styku materiałów.\(angleNote)",
        room: room,
        rowsInstructionPl: lines,
        splitAtMm: splitAtMm,
        splitAxis: splitAxis,
        warnings: warnings,
        windows: []
    )
}
