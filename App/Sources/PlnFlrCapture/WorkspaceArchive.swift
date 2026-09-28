import ComposableArchitecture2
import Foundation
import PlnFlrLayout

/// Durable inputs only. Plans are derived; App Store entitlements never come from this file.
public struct WorkspaceArchive: Codable, Equatable, Sendable {
    public var freeRoomID: UUID?
    public var version = 1
    public var projects: [ProjectRecord]
    public var selectedProjectID: UUID?

    public init(_ state: Workspace.State) {
        freeRoomID = state.freeRoomID
        projects = state.projects.map(ProjectRecord.init)
        selectedProjectID = state.selectedProjectID
    }

    public var state: Workspace.State {
        var state = Workspace.State(projects: projects.map(\.state), selectedProjectID: selectedProjectID)
        state.freeRoomID = freeRoomID
        return state
    }

    public struct ProjectRecord: Codable, Equatable, Sendable {
        var id: UUID
        var name: String
        var scans: [ScanRecord]
        var floors: [FloorRecord]
        var selectedFloorIDs: [UUID]
        var splitAtM: String
        var splitAxis: SplitAxis
        var geometryCorrections: [GeometryCorrection]
        var undoneGeometryCorrectionIDs: [UUID]
        var scanPlacements: [ScanPlacement]
        var undoneScanPlacementIDs: [UUID]
        var floorVariants: [FloorVariant]
        var undoneFloorVariantIDs: [UUID]
        var walls: [WallSegment]
        var utilities: [UtilityRoute]
        var furniture: [FurnitureItem]

        init(_ state: Workspace.Project.State) {
            id = state.id
            name = state.name
            scans = state.scans.map { ScanRecord(id: $0.id, label: $0.label, rooms: $0.rooms, roomPlanJSON: $0.roomPlanJSON, roomPlanStructure: $0.roomPlanStructure, sourceUsdz: $0.sourceUsdz, transform: $0.transform) }
            floors = state.floors.map(FloorRecord.init)
            selectedFloorIDs = state.selectedFloorIDs
            splitAtM = state.splitAtM
            splitAxis = state.splitAxis
            geometryCorrections = state.geometryCorrections
            undoneGeometryCorrectionIDs = state.undoneGeometryCorrectionIDs
            scanPlacements = state.scanPlacements
            undoneScanPlacementIDs = state.undoneScanPlacementIDs
            floorVariants = state.floorVariants
            undoneFloorVariantIDs = state.undoneFloorVariantIDs
            walls = state.walls
            utilities = state.utilities
            furniture = state.furniture
        }

        private enum CodingKeys: String, CodingKey {
            case id, name, scans, floors, selectedFloorIDs, splitAtM, splitAxis, geometryCorrections, undoneGeometryCorrectionIDs, scanPlacements, undoneScanPlacementIDs, floorVariants, undoneFloorVariantIDs, walls, utilities, furniture
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            scans = try container.decode([ScanRecord].self, forKey: .scans)
            floors = try container.decode([FloorRecord].self, forKey: .floors)
            selectedFloorIDs = try container.decode([UUID].self, forKey: .selectedFloorIDs)
            splitAtM = try container.decode(String.self, forKey: .splitAtM)
            splitAxis = try container.decode(SplitAxis.self, forKey: .splitAxis)
            geometryCorrections = try container.decodeIfPresent([GeometryCorrection].self, forKey: .geometryCorrections) ?? []
            undoneGeometryCorrectionIDs = try container.decodeIfPresent([UUID].self, forKey: .undoneGeometryCorrectionIDs) ?? []
            scanPlacements = try container.decodeIfPresent([ScanPlacement].self, forKey: .scanPlacements) ?? []
            undoneScanPlacementIDs = try container.decodeIfPresent([UUID].self, forKey: .undoneScanPlacementIDs) ?? []
            floorVariants = try container.decodeIfPresent([FloorVariant].self, forKey: .floorVariants) ?? []
            undoneFloorVariantIDs = try container.decodeIfPresent([UUID].self, forKey: .undoneFloorVariantIDs) ?? []
            walls = try container.decodeIfPresent([WallSegment].self, forKey: .walls) ?? []
            utilities = try container.decodeIfPresent([UtilityRoute].self, forKey: .utilities) ?? []
            furniture = try container.decodeIfPresent([FurnitureItem].self, forKey: .furniture) ?? []
        }

        var state: Workspace.Project.State {
            .init(id: id, name: name, scans: scans.map { .init(id: $0.id, label: $0.label, rooms: $0.rooms, roomPlanJSON: $0.roomPlanJSON, roomPlanStructure: $0.roomPlanStructure, sourceUsdz: $0.sourceUsdz, transform: $0.transform) },
                  floors: floors.map(\.state), selectedFloorIDs: selectedFloorIDs,
                  splitAtM: splitAtM, splitAxis: splitAxis, geometryCorrections: geometryCorrections,
                  undoneGeometryCorrectionIDs: undoneGeometryCorrectionIDs,
                  scanPlacements: scanPlacements, undoneScanPlacementIDs: undoneScanPlacementIDs,
                  floorVariants: floorVariants, undoneFloorVariantIDs: undoneFloorVariantIDs,
                  walls: walls, utilities: utilities, furniture: furniture)
        }
    }

    public struct ScanRecord: Codable, Equatable, Sendable {
        var id: UUID
        var label: String
        var rooms: [CapturedRoom]
        var roomPlanJSON: Data?
        var roomPlanStructure: RoomPlanStructureSource?
        var sourceUsdz: Data?
        var transform: ScanTransform

        init(id: UUID, label: String, rooms: [CapturedRoom], roomPlanJSON: Data? = nil, roomPlanStructure: RoomPlanStructureSource? = nil, sourceUsdz: Data? = nil, transform: ScanTransform = .identity) {
            self.id = id
            self.label = label
            self.rooms = rooms
            self.roomPlanJSON = roomPlanJSON
            self.roomPlanStructure = roomPlanStructure
            self.sourceUsdz = sourceUsdz
            self.transform = transform
        }

        private enum CodingKeys: String, CodingKey {
            case id, label, rooms, roomPlanJSON, roomPlanStructure, sourceUsdz, transform
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            label = try container.decode(String.self, forKey: .label)
            rooms = try container.decode([CapturedRoom].self, forKey: .rooms)
            roomPlanJSON = try container.decodeIfPresent(Data.self, forKey: .roomPlanJSON)
            roomPlanStructure = try container.decodeIfPresent(RoomPlanStructureSource.self, forKey: .roomPlanStructure)
            sourceUsdz = try container.decodeIfPresent(Data.self, forKey: .sourceUsdz)
            transform = try container.decodeIfPresent(ScanTransform.self, forKey: .transform) ?? .identity
        }
    }

    public struct FloorRecord: Codable, Equatable, Sendable {
        var material: FloorMaterial
        var packSize: String
        var groutMm: String
        var accessID: UUID
        var id: UUID
        var name: String
        var room: Room
        var thresholds: [Threshold]
        var windows: [Opening]
        var expansionMm: String
        var finish: FloorFinish?
        var plankLengthM: String
        var plankWidthM: String

        init(_ state: Workspace.Floor.State) {
            material = state.material
            packSize = state.packSize
            groutMm = state.groutMm
            accessID = state.accessID
            id = state.id
            name = state.name
            room = state.room
            thresholds = state.thresholds
            windows = state.windows
            expansionMm = state.expansionMm
            finish = state.finish
            plankLengthM = state.plankLengthM
            plankWidthM = state.plankWidthM
        }

        var state: Workspace.Floor.State {
            var state = Workspace.Floor.State(id: id, name: name, room: room, thresholds: thresholds, windows: windows,
                  expansionMm: expansionMm, plankLengthM: plankLengthM, plankWidthM: plankWidthM, accessID: accessID)
            state.material = material
            state.packSize = packSize
            state.groutMm = groutMm
            state.finish = finish ?? .oak
            return state
        }
    }
}

public struct WorkspaceStorage: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public static var live: Self {
        Self(url: URL.applicationSupportDirectory.appendingPathComponent("PlnFlr/workspace.json"))
    }

    public func load() throws -> WorkspaceArchive {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return WorkspaceArchive(Workspace.State())
        }
        let archive = try JSONDecoder().decode(WorkspaceArchive.self, from: Data(contentsOf: url))
        guard archive.version == 1 else { throw ArchiveError.unsupportedVersion }
        for project in archive.projects {
            for floor in project.floors {
                try validateRoom(outer: floor.room.outer.vertices, holes: floor.room.holes.map(\.vertices))
            }
        }
        return archive
    }

    public func save(_ archive: WorkspaceArchive) throws {
        let data = try JSONEncoder().encode(archive)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

enum ArchiveError: LocalizedError {
    case unsupportedVersion
    var errorDescription: String? { "Ten projekt zapisano w nowszej wersji PlnFlr. Zaktualizuj aplikację." }
}

struct WorkspaceFiles: Sendable {
    var load: @Sendable () throws -> WorkspaceArchive
    var save: @Sendable (WorkspaceArchive) throws -> Void

    static var live: Self {
        let storage = WorkspaceStorage.live
        return Self(load: { try storage.load() }, save: { try storage.save($0) })
    }
}

extension FeatureEnvironmentValues {
    @FeatureEnvironmentEntry(liveValue: WorkspaceFiles.live)
    var workspaceFiles = WorkspaceFiles(load: { WorkspaceArchive(Workspace.State()) }, save: { _ in })
}
