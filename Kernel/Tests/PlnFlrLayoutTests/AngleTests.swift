import PlnFlrLayout
import Testing

private func axisAligned(_ geometry: [Vertex]) -> Bool {
    Set(geometry.map(\.xMm)).count <= 2 && Set(geometry.map(\.yMm)).count <= 2
}

@Test func zeroAngleStaysAxisAligned() throws {
    let plan = try layoutPlanks(
        try rectangle(widthMm: 4000, heightMm: 3000),
        PlankSpec(lengthMm: 1383, widthMm: 156),
        LayoutRules(expansionMm: 10, angleDeg: 0)
    )
    #expect(plan.angleDeg == 0)
    #expect(plan.pieces.contains { axisAligned($0.geometry) })
}

@Test func fortyFiveDegreePiecesAreRotated() throws {
    let plan = try layoutPlanks(
        try rectangle(widthMm: 4000, heightMm: 3000),
        PlankSpec(lengthMm: 1383, widthMm: 156),
        LayoutRules(expansionMm: 10, angleDeg: 45)
    )
    #expect(plan.angleDeg == 45)
    #expect(!plan.pieces.isEmpty)
    #expect(plan.pieces.contains { !axisAligned($0.geometry) })
    #expect(plan.rationalePl.contains("45"))
}
