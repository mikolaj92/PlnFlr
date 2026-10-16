import Foundation
#if os(iOS)
import RoomPlan
#endif

/// Full Apple encodings: original rooms plus StructureBuilder's assembled result.
/// All rooms must come from one uninterrupted AR session, not independent captures.
public struct RoomPlanStructureSource: Codable, Equatable, Sendable {
    public var rooms: [Data]
    public var structure: Data

    /// RoomPlan source geometry is preserved, but accuracy has not been verified against reference measurements.
    public static let unverifiedAccuracyDisclosure = "Źródło RoomPlan zachowano. Dokładność geometrii nie została zweryfikowana względem pomiarów referencyjnych; sprawdź wymiary przed użyciem do planowania."

    public var accuracyDisclosure: String { Self.unverifiedAccuracyDisclosure }

    public static func listedSourceTitle(label: String, roomCount: Int?, hasSourceUsdz: Bool) -> String? {
        if let roomCount {
            return "\(label) · \(roomCount) pokoi z jednej sesji RoomPlan"
        }
        if hasSourceUsdz {
            return "\(label) · oryginalny USDZ zachowany"
        }
        return nil
    }

    public init(rooms: [Data], structure: Data) {
        self.rooms = rooms
        self.structure = structure
    }
}

#if os(iOS)
enum RoomPlanStructurePreview {
    static func exportURL(_ source: RoomPlanStructureSource) throws -> URL {
        let structure = try JSONDecoder().decode(RoomPlan.CapturedStructure.self, from: source.structure)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).usdz")
        try structure.export(to: url, exportOptions: .mesh)
        return url
    }
}
#endif
