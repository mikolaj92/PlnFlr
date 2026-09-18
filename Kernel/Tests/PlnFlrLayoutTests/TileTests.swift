import PlnFlrLayout
import Testing

@Test func tilesCoverInset() throws {
    let plan = try layoutTiles(
        try rectangle(widthMm: 2010, heightMm: 2010),
        TileSpec(lengthMm: 600, widthMm: 600, groutMm: 3),
        LayoutRules(expansionMm: 10)
    )
    #expect(!plan.pieces.isEmpty)
    #expect(plan.bom.fullBoards > 0)
}
