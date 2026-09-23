public struct Ring: Codable, Equatable, Hashable, Sendable {
    public var vertices: [Vertex]

    public init(_ vertices: [Vertex]) throws {
        guard vertices.count >= 3 else { throw LayoutError.ringNeedsThreeVertices }
        self.vertices = vertices
    }
}

public struct Room: Codable, Equatable, Hashable, Sendable {
    public var outer: Ring
    public var holes: [Ring]

    public init(_ outer: Ring, holes: [Ring] = []) {
        self.outer = outer
        self.holes = holes
    }
}

public enum Stagger: String, Equatable, Sendable {
    case half
    case third
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

public enum SplitAxis: String, Codable, Equatable, Hashable, Sendable {
    case x
    case y
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
    public var minTileCutMm: Int
    public var stagger: Stagger

    public init(
        expansionMm: Int? = nil,
        expansionMinMm: Int = 10,
        expansionPerMMm: String = "1.5",
        minRowWidthMm: Int = 50,
        minEndLengthMm: Int = 300,
        stagger: Stagger = .third,
        direction: LayDirection = .alongLong,
        minTileCutMm: Int = 30,
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
        self.minTileCutMm = minTileCutMm
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

public struct TileSpec: Equatable, Sendable {
    public var groutMm: Int
    public var lengthMm: Int
    public var tilesPerPack: Int?
    public var widthMm: Int

    public init(lengthMm: Int, widthMm: Int, groutMm: Int = 3, tilesPerPack: Int? = nil) {
        self.groutMm = groutMm
        self.lengthMm = lengthMm
        self.tilesPerPack = tilesPerPack
        self.widthMm = widthMm
    }
}

public enum ZoneKind: String, Equatable, Sendable {
    case mixed
    case plank
    case tile
}

public struct Zone: Equatable, Sendable {
    public var angleDeg: Int?
    public var kind: ZoneKind
    public var label: String?
    public var plank: PlankSpec?
    public var tile: TileSpec?

    public init(
        kind: ZoneKind,
        plank: PlankSpec? = nil,
        tile: TileSpec? = nil,
        angleDeg: Int? = nil,
        label: String? = nil
    ) {
        self.angleDeg = angleDeg
        self.kind = kind
        self.label = label
        self.plank = plank
        self.tile = tile
    }
}

public struct Opening: Codable, Equatable, Hashable, Sendable {
    public var end: Vertex
    public var label: String
    public var start: Vertex

    public init(label: String, start: Vertex, end: Vertex) {
        self.end = end
        self.label = label
        self.start = start
    }
}

public struct Threshold: Codable, Equatable, Hashable, Sendable {
    public var geometry: Ring
    public var label: String
    public var lengthMm: Int
    public var widthMm: Int

    public init(label: String, lengthMm: Int, widthMm: Int, geometry: Ring) {
        self.geometry = geometry
        self.label = label
        self.lengthMm = lengthMm
        self.widthMm = widthMm
    }
}

public enum PieceKind: String, Equatable, Sendable {
    case clip
    case endCut = "end_cut"
    case full
    case rip
    case startCut = "start_cut"
    case tileCut = "tile_cut"
    case tileFull = "tile_full"
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
    public var zoneIndex: Int

    public init(
        geometry: [Vertex],
        installOrder: Int,
        kind: PieceKind,
        lengthMm: Int,
        pieceId: String,
        rowIndex: Int,
        sourceBoard: Int,
        widthMm: Int,
        zoneIndex: Int = 0
    ) {
        self.geometry = geometry
        self.installOrder = installOrder
        self.kind = kind
        self.lengthMm = lengthMm
        self.pieceId = pieceId
        self.rowIndex = rowIndex
        self.sourceBoard = sourceBoard
        self.widthMm = widthMm
        self.zoneIndex = zoneIndex
    }
}

public struct Warning: Equatable, Sendable {
    public var code: String
    public var messagePl: String
}

public struct BillOfMaterials: Equatable, Sendable {
    public var areaBoughtMm2: Int
    public var areaNetMm2: Int
    public var fullBoards: Int
    public var kind: ZoneKind
    public var label: String
    public var packs: Int?
    public var pieces: Int
    public var wastePct: String
}

public struct LayoutPlan: Sendable {
    public var angleDeg: Int
    public var bom: BillOfMaterials
    public var boms: [BillOfMaterials]
    public var direction: Axis
    public var divider: (Vertex, Vertex)?
    public var gapMm: Int
    public var inset: Room
    public var pieces: [Piece]
    public var rationalePl: String
    public var room: Room
    public var rowsInstructionPl: [String]
    public var splitAtMm: Int?
    public var splitAxis: SplitAxis?
    public var thresholds: [Threshold] = []
    public var warnings: [Warning]
    public var windows: [Opening]
}

extension LayoutPlan: Equatable {
    public static func == (lhs: LayoutPlan, rhs: LayoutPlan) -> Bool {
        lhs.angleDeg == rhs.angleDeg
            && lhs.bom == rhs.bom
            && lhs.boms == rhs.boms
            && lhs.direction == rhs.direction
            && lhs.gapMm == rhs.gapMm
            && lhs.inset == rhs.inset
            && lhs.pieces == rhs.pieces
            && lhs.rationalePl == rhs.rationalePl
            && lhs.room == rhs.room
            && lhs.rowsInstructionPl == rhs.rowsInstructionPl
            && lhs.splitAtMm == rhs.splitAtMm
            && lhs.splitAxis == rhs.splitAxis
            && lhs.thresholds == rhs.thresholds
            && lhs.warnings == rhs.warnings
            && lhs.windows == rhs.windows
            && optionalPairEqual(lhs.divider, rhs.divider)
    }
}

private func optionalPairEqual(_ a: (Vertex, Vertex)?, _ b: (Vertex, Vertex)?) -> Bool {
    switch (a, b) {
    case (nil, nil): true
    case let (l?, r?): l.0 == r.0 && l.1 == r.1
    default: false
    }
}
