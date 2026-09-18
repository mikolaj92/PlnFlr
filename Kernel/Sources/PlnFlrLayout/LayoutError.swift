public enum LayoutError: Error, Equatable, Sendable {
    case cutoutMustBeSmallerThanSpan
    case expansionMustBeNonNegative
    case invalidExpansionRate
    case lShapeDimensionsMustBePositive
    case rectangleSidesMustBePositive
    case ringNeedsThreeVertices
}
