import Foundation

public enum LayoutError: Error, Equatable, Sendable, LocalizedError {
    case cutoutMustBeSmallerThanSpan
    case expansionGapLeavesNoArea
    case expansionMustBeNonNegative
    case invalidExpansionRate
    case invalidMetres
    case lShapeDimensionsMustBePositive
    case metresMustBeNonNegative
    case metresMustBePositive
    case needAtLeastOneZone
    case plankZoneMissingSpec
    case rectangleSidesMustBePositive
    case ringNeedsThreeVertices
    case selfIntersectingPolygon
    case spansMustBePositive
    case splitLeavesNoArea
    case tileZoneMissingSpec

    public var errorDescription: String? {
        switch self {
        case .cutoutMustBeSmallerThanSpan: "cutout must be smaller than span"
        case .expansionGapLeavesNoArea: "expansion gap leaves no installable area"
        case .expansionMustBeNonNegative: "expansion must be >= 0"
        case .invalidExpansionRate: "invalid expansion rate"
        case .invalidMetres: "invalid metres"
        case .lShapeDimensionsMustBePositive: "L dimensions must be positive"
        case .metresMustBeNonNegative: "metres must be non-negative"
        case .metresMustBePositive: "metres must be positive"
        case .needAtLeastOneZone: "need at least one zone"
        case .plankZoneMissingSpec: "plank zone missing spec"
        case .rectangleSidesMustBePositive: "rectangle sides must be positive"
        case .ringNeedsThreeVertices: "ring needs ≥ 3 vertices"
        case .selfIntersectingPolygon: "self-intersecting polygon"
        case .spansMustBePositive: "spans must be positive"
        case .splitLeavesNoArea: "split leaves no area"
        case .tileZoneMissingSpec: "tile zone missing spec"
        }
    }
}
