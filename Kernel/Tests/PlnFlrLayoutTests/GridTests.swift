import PlnFlrLayout
import Testing

@Test func sliverIsRedistributed() throws {
    let rows = try splitRows(innerMm: 2980, plankWidthMm: 156, minRowWidthMm: 50)
    #expect(rows.reduce(0, +) == 2980)
    #expect(rows.allSatisfy { $0 >= 50 })
    #expect(abs(rows[0] - rows[rows.count - 1]) <= 1)
}

@Test func exactFitAllFull() throws {
    let rows = try splitRows(innerMm: 1560, plankWidthMm: 156, minRowWidthMm: 50)
    #expect(rows == Array(repeating: 156, count: 10))
}
