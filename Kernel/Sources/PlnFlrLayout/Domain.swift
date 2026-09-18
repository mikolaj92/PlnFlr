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

public enum Stagger: String, Equatable, Sendable {
    case third
    case half
}

public enum LayDirection: String, Equatable, Sendable {
    case alongLong = "along_long"
    case alongShort = "along_short"
    case alongX = "along_x"
    case alongY = "along_y"
    case intoWindow = "into_window"
}

public enum Axis: String, Equatable, Sendable {
    case alongX = "along_x"
    case alongY = "along_y"
}

public struct LayoutRules: Equatable, Sendable {
    public var angleDeg: Int
    public var direction: LayDirection
    public var expansionMinMm: Int
    public var expansionMm: Int?
    public var expansionPerMMm: String
    public var intermediateJointMm: Int
    public var minEndLengthMm: Int
    public var minRowWidthMm: Int
    public var stagger: Stagger

    public init(
        expansionMm: Int? = nil,
        expansionMinMm: Int = 10,
        expansionPerMMm: String = "1.5",
        minRowWidthMm: Int = 50,
        minEndLengthMm: Int = 300,
        stagger: Stagger = .third,
        direction: LayDirection = .alongLong,
        intermediateJointMm: Int = 8000,
        angleDeg: Int = 0
    ) {
        self.angleDeg = angleDeg
        self.direction = direction
        self.expansionMinMm = expansionMinMm
        self.expansionMm = expansionMm
        self.expansionPerMMm = expansionPerMMm
        self.intermediateJointMm = intermediateJointMm
        self.minEndLengthMm = minEndLengthMm
        self.minRowWidthMm = minRowWidthMm
        self.stagger = stagger
    }
}

public struct PlankSpec: Equatable, Sendable {
    public var boardsPerPack: Int?
    public var lengthMm: Int
    public var widthMm: Int

    public init(lengthMm: Int, widthMm: Int, boardsPerPack: Int? = nil) {
        self.boardsPerPack = boardsPerPack
        self.lengthMm = lengthMm
        self.widthMm = widthMm
    }
}

public struct Opening: Equatable, Hashable, Sendable {
    public var end: Vertex
    public var label: String
    public var start: Vertex

    public init(label: String, start: Vertex, end: Vertex) {
        self.end = end
        self.label = label
        self.start = start
    }
}

public enum PieceKind: String, Equatable, Sendable {
    case clip
    case endCut = "end_cut"
    case full
    case rip
    case startCut = "start_cut"
}

public struct Piece: Equatable, Sendable {
    public var geometry: [Vertex]
    public var installOrder: Int
    public var kind: PieceKind
    public var lengthMm: Int
    public var pieceId: String
    public var rowIndex: Int
    public var sourceBoard: Int
    public var widthMm: Int
}

public struct Warning: Equatable, Sendable {
    public var code: String
    public var messagePl: String
}

public struct BillOfMaterials: Equatable, Sendable {
    public var areaBoughtMm2: Int
    public var areaNetMm2: Int
    public var fullBoards: Int
    public var packs: Int?
    public var pieces: Int
    public var wastePct: String
}

public struct LayoutPlan: Equatable, Sendable {
    public var bom: BillOfMaterials
    public var direction: Axis
    public var gapMm: Int
    public var inset: Room
    public var pieces: [Piece]
    public var rationalePl: String
    public var room: Room
    public var rowsInstructionPl: [String]
    public var warnings: [Warning]
    public var windows: [Opening]
}
