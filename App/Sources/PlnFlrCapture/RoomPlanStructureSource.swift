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

    public static let appearanceDisclosure = "Podgląd wyglądu — nie katalog produktu ani pomiar"

    public var accuracyDisclosure: String { Self.unverifiedAccuracyDisclosure }

    static func wallAppearanceLimitation(_ scan: Workspace.Scan.State) -> String {
        guard scan.roomPlanStructure != nil || scan.roomPlanJSON != nil else {
            return "Zmiana koloru niedostępna: brak zachowanych danych ścian RoomPlan. Sam USDZ nie potwierdza, które powierzchnie są ścianami."
        }
        return "Zmiana koloru niedostępna: powiązanie ścian RoomPlan z powierzchniami modelu nie zostało zweryfikowane na rzeczywistym eksporcie. Nie tworzymy ścian z obrysu podłogi."
    }

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
