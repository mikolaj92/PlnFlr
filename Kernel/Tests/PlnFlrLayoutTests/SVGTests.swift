import PlnFlrLayout
import Testing

@Test func svgHasViewBoxAndPieces() throws {
    let plan = try layoutPlanks(
        try rectangle(widthMm: 4000, heightMm: 3000),
        PlankSpec(lengthMm: 1383, widthMm: 156),
        LayoutRules(expansionMm: 10)
    )
    let svg = planToSvg(plan)
    #expect(svg.contains("<svg"))
    #expect(svg.contains("viewBox"))
    let paths = svg.components(separatedBy: "<path").count - 1
    let rects = svg.components(separatedBy: "<rect").count - 1
    #expect(paths + rects >= plan.pieces.count)
}

@Test func svgDrawsWindowOpening() throws {
    let window = Opening(label: "okno", start: Vertex(1000, 0), end: Vertex(2000, 0))
    let plan = try layoutPlanks(
        try rectangle(widthMm: 4000, heightMm: 3000),
        PlankSpec(lengthMm: 1383, widthMm: 156),
        LayoutRules(expansionMm: 10),
        windows: [window]
    )
    let svg = planToSvg(plan)
    #expect(svg.contains("pln-window"))
    #expect(svg.contains("x1=\"1000\""))
    #expect(svg.contains("x2=\"2000\""))
}
