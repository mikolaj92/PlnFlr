import Foundation

public func bbox(_ room: Room) -> (minX: Int, minY: Int, maxX: Int, maxY: Int) {
    let xs = room.outer.vertices.map(\.xMm)
    let ys = room.outer.vertices.map(\.yMm)
    return (xs.min() ?? 0, ys.min() ?? 0, xs.max() ?? 0, ys.max() ?? 0)
}

public func resolveGapMm(_ room: Room, _ rules: LayoutRules) throws -> Int {
    if let gap = rules.expansionMm {
        guard gap >= 0 else { throw LayoutError.expansionMustBeNonNegative }
        return gap
    }
    let bounds = bbox(room)
    let longestMm = max(bounds.maxX - bounds.minX, bounds.maxY - bounds.minY)
    guard let rate = Decimal(string: rules.expansionPerMMm) else {
        throw LayoutError.invalidExpansionRate
    }
    var value = Decimal(longestMm) / Decimal(1000) * rate
    var rounded = Decimal()
    NSDecimalRound(&rounded, &value, 0, .up)
    let auto = NSDecimalNumber(decimal: rounded).intValue
    return max(rules.expansionMinMm, auto)
}
