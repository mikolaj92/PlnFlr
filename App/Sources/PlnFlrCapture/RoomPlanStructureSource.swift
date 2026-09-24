import Foundation

/// Full Apple encodings: original rooms plus StructureBuilder's assembled result.
/// All rooms must come from one uninterrupted AR session, not independent captures.
public struct RoomPlanStructureSource: Codable, Equatable, Sendable {
    public var rooms: [Data]
    public var structure: Data

    public init(rooms: [Data], structure: Data) {
        self.rooms = rooms
        self.structure = structure
    }
}
