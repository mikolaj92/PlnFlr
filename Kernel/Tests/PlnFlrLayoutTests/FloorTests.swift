import PlnFlrLayout
import Testing

@Test func splitHalfPlankHalfTile() throws {
    let plan = try layoutFloor(
        try rectangle(widthMm: 4000, heightMm: 3000),
        zones: [
            Zone(kind: .plank, plank: PlankSpec(lengthMm: 1383, widthMm: 156, boardsPerPack: 8)),
            Zone(kind: .tile, tile: TileSpec(lengthMm: 600, widthMm: 600, groutMm: 3)),
        ],
        rules: LayoutRules(expansionMm: 10),
        splitAxis: .x,
        splitAtMm: 2000
    )
    let kinds = Set(plan.pieces.map(\.kind))
    #expect(!kinds.isDisjoint(with: [.full, .startCut, .endCut, .rip, .clip]))
    #expect(!kinds.isDisjoint(with: [.tileFull, .tileCut]))
    #expect(plan.boms.count == 2)
    let labels = plan.boms.map(\.label).joined(separator: " ")
    #expect(labels.contains("Panele"))
    #expect(labels.contains("Płytki"))
    #expect(plan.splitAxis == .x)
    #expect(plan.splitAtMm == 2000)
}
