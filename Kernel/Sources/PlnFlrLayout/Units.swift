import Foundation

public func metresToMm(_ value: String) throws -> Int {
    let metres = try parseMetres(value)
    guard metres > 0 else { throw LayoutError.metresMustBePositive }
    return toMm(metres)
}

public func metresToMmCoord(_ value: String) throws -> Int {
    let metres = try parseMetres(value)
    guard metres >= 0 else { throw LayoutError.metresMustBeNonNegative }
    return toMm(metres)
}

public func mmToMetresStr(_ millimetres: Int) -> String {
    String(format: "%.3f", Double(millimetres) / 1000.0)
}

private func parseMetres(_ value: String) throws -> Decimal {
    guard let metres = Decimal(string: value) else { throw LayoutError.invalidMetres }
    return metres
}

private func toMm(_ metres: Decimal) -> Int {
    var scaled = metres * 1000
    var rounded = Decimal()
    NSDecimalRound(&rounded, &scaled, 0, .plain)
    return NSDecimalNumber(decimal: rounded).intValue
}
