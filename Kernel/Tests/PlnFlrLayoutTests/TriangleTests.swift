import PlnFlrLayout
import Testing

@Test func triangleClips() throws {
    let room = Room(
        try Ring([Vertex(0, 0), Vertex(4000, 0), Vertex(0, 3000)])
    )
    let plan = try layoutPlanks(
        room,
        PlankSpec(lengthMm: 1383, widthMm: 156),
        LayoutRules(expansionMm: 10)
    )
    #expect(plan.pieces.contains { $0.geometry.count > 4 || $0.kind == .clip })
    let covered = plan.pieces.reduce(0) { $0 + areaMm2($1.geometry) }
    #expect(abs(covered - plan.bom.areaNetMm2) <= max(2 * plan.pieces.count, 50))
}
