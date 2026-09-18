public enum LayoutError: Error, Equatable, Sendable {
    case cutoutMustBeSmallerThanSpan
    case expansionGapLeavesNoArea
    case expansionMustBeNonNegative
    case invalidExpansionRate
    case lShapeDimensionsMustBePositive
    case rectangleSidesMustBePositive
    case ringNeedsThreeVertices
    case selfIntersectingPolygon
    case spansMustBePositive
}
