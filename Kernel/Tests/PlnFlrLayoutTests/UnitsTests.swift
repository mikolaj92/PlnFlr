import PlnFlrLayout
import Testing

@Test func metresToMmConvertsWholeMetres() throws {
    #expect(try metresToMm("4") == 4000)
}

@Test func metresToMmRoundsHalfUpToNearestMillimetre() throws {
    #expect(try metresToMm("1.2345") == 1235)
}

@Test(arguments: ["0", "-1", "-0.001"])
func metresToMmRejectsZeroAndNegatives(_ value: String) {
    #expect(throws: LayoutError.metresMustBePositive) {
        try metresToMm(value)
    }
}

@Test func metresToMmCoordAllowsOrigin() throws {
    #expect(try metresToMmCoord("0") == 0)
    #expect(try metresToMmCoord("4") == 4000)
}

@Test(arguments: ["-1", "-0.001"])
func metresToMmCoordRejectsNegatives(_ value: String) {
    #expect(throws: LayoutError.metresMustBeNonNegative) {
        try metresToMmCoord(value)
    }
}

@Test func mmToMetresStrFormatsThreeDecimalPlaces() {
    #expect(mmToMetresStr(4000) == "4.000")
}
