public enum LayoutError: Error, Equatable, Sendable {
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
}
