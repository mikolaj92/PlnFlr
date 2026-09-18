/// Integer millimetre point. Coordinates are not lengths.
public struct Vertex: Equatable, Hashable, Sendable {
    public var xMm: Int
    public var yMm: Int

    public init(_ xMm: Int, _ yMm: Int) {
        self.xMm = xMm
        self.yMm = yMm
    }
}
