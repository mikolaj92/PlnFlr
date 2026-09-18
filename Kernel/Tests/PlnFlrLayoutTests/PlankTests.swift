import PlnFlrLayout
import Testing

private func covered(_ plan: LayoutPlan) -> Int {
    plan.pieces.reduce(0) { $0 + areaMm2($1.geometry) }
}

@Test func rectanglePiecesCoverInset() throws {
    let plan = try layoutPlanks(
        try rectangle(widthMm: 4000, heightMm: 3000),
        PlankSpec(lengthMm: 1383, widthMm: 156, boardsPerPack: 8),
        LayoutRules(expansionMm: 10)
    )
    #expect(plan.gapMm == 10)
    #expect(!plan.pieces.isEmpty)
    #expect(abs(covered(plan) - plan.bom.areaNetMm2) <= max(plan.pieces.count, 1))
    #expect(plan.pieces.allSatisfy { $0.widthMm >= 50 })
    #expect(plan.bom.fullBoards > 0)
    #expect(plan.bom.packs == (plan.bom.fullBoards + 7) / 8)
    #expect(plan.rowsInstructionPl.joined(separator: "\n").contains("Rząd 1"))
}

@Test func lShapeHasPieces() throws {
    let plan = try layoutPlanks(
        try lShape(spanXMm: 6000, spanYMm: 4000, cutoutXMm: 2500, cutoutYMm: 2000),
        PlankSpec(lengthMm: 1383, widthMm: 156),
        LayoutRules(expansionMm: 10)
    )
    #expect(!plan.pieces.isEmpty)
    #expect(abs(covered(plan) - plan.bom.areaNetMm2) <= max(plan.pieces.count, 1))
    #expect(Set(plan.pieces.map(\.rowIndex)).count > 1)
}

@Test func intoWindowRunsBoardsPerpendicularToWindowWall() throws {
    let window = Opening(label: "okno", start: Vertex(1000, 0), end: Vertex(2000, 0))
    let plan = try layoutPlanks(
        try rectangle(widthMm: 4000, heightMm: 3000),
        PlankSpec(lengthMm: 1383, widthMm: 156),
        LayoutRules(expansionMm: 10, direction: .intoWindow),
        windows: [window]
    )
    #expect(plan.windows == [window])
    let full = try #require(plan.pieces.first { $0.kind == .full })
    let dx = full.geometry.map(\.xMm).max()! - full.geometry.map(\.xMm).min()!
    let dy = full.geometry.map(\.yMm).max()! - full.geometry.map(\.yMm).min()!
    #expect(dy > dx)
    #expect(plan.rationalePl.lowercased().contains("okna"))
}

@Test func holeSplitsBoard() throws {
    let hole = try Ring([
        Vertex(1800, 1200),
        Vertex(2200, 1200),
        Vertex(2200, 1800),
        Vertex(1800, 1800),
    ])
    let room = Room(try rectangle(widthMm: 4000, heightMm: 3000).outer, holes: [hole])
    let plan = try layoutPlanks(
        room,
        PlankSpec(lengthMm: 1383, widthMm: 156),
        LayoutRules(expansionMm: 10)
    )
    let counts = Dictionary(grouping: plan.pieces, by: \.sourceBoard).mapValues(\.count)
    #expect(counts.values.max() ?? 0 >= 2)
}

@Test func longRoomWarnsIntermediateJoint() throws {
    let plan = try layoutPlanks(
        try rectangle(widthMm: 12000, heightMm: 4000),
        PlankSpec(lengthMm: 1383, widthMm: 156),
        LayoutRules()
    )
    #expect(plan.warnings.contains { $0.code == "intermediate_joint" })
}
