public struct Ring: Equatable, Hashable, Sendable {
    public var vertices: [Vertex]

    public init(_ vertices: [Vertex]) throws {
        guard vertices.count >= 3 else { throw LayoutError.ringNeedsThreeVertices }
        self.vertices = vertices
    }
}

public struct Room: Equatable, Hashable, Sendable {
    public var outer: Ring
    public var holes: [Ring]

    public init(_ outer: Ring, holes: [Ring] = []) {
        self.outer = outer
        self.holes = holes
    }
}

public struct LayoutRules: Equatable, Sendable {
    public var expansionMinMm: Int
    public var expansionMm: Int?
    public var expansionPerMMm: String

    public init(
        expansionMm: Int? = nil,
        expansionMinMm: Int = 10,
        expansionPerMMm: String = "1.5"
    ) {
        self.expansionMinMm = expansionMinMm
        self.expansionMm = expansionMm
        self.expansionPerMMm = expansionPerMMm
    }
}
