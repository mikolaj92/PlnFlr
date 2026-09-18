public func rectangle(widthMm: Int, heightMm: Int) throws -> Room {
    guard widthMm > 0, heightMm > 0 else {
        throw LayoutError.rectangleSidesMustBePositive
    }
    return Room(
        try Ring([
            Vertex(0, 0),
            Vertex(widthMm, 0),
            Vertex(widthMm, heightMm),
            Vertex(0, heightMm),
        ])
    )
}

public func lShape(
    spanXMm: Int,
    spanYMm: Int,
    cutoutXMm: Int,
    cutoutYMm: Int
) throws -> Room {
    guard min(spanXMm, spanYMm, cutoutXMm, cutoutYMm) > 0 else {
        throw LayoutError.lShapeDimensionsMustBePositive
    }
    guard cutoutXMm < spanXMm, cutoutYMm < spanYMm else {
        throw LayoutError.cutoutMustBeSmallerThanSpan
    }
    let keepX = spanXMm - cutoutXMm
    let keepY = spanYMm - cutoutYMm
    return Room(
        try Ring([
            Vertex(0, 0),
            Vertex(spanXMm, 0),
            Vertex(spanXMm, keepY),
            Vertex(keepX, keepY),
            Vertex(keepX, spanYMm),
            Vertex(0, spanYMm),
        ])
    )
}
