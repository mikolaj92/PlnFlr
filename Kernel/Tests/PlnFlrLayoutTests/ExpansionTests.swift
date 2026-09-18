import PlnFlrLayout
import Testing

@Test func explicitGapOnRectangle() throws {
    let room = try rectangle(widthMm: 4000, heightMm: 3000)
    let gap = try resolveGapMm(room, LayoutRules(expansionMm: 12))
    #expect(gap == 12)
}

@Test func autoGapUsesLongestBboxSide() throws {
    let room = try rectangle(widthMm: 8000, heightMm: 3000)
    #expect(try resolveGapMm(room, LayoutRules()) == 12)
}

@Test func autoGapRespectsMinimum() throws {
    let room = try rectangle(widthMm: 4000, heightMm: 3000)
    #expect(try resolveGapMm(room, LayoutRules()) == 10)
}
