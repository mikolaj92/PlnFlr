import ComposableArchitecture2
import Foundation
import PlnFlrLayout

/// Durable inputs only. Plans are derived; App Store entitlements never come from this file.
public struct WorkspaceArchive: Codable, Equatable, Sendable {
    public var freeRoomID: UUID?
    public var version = 2
    public var projects: [ProjectRecord]
    public var selectedProjectID: UUID?

    public init(_ state: Workspace.State) {
        freeRoomID = state.freeRoomID
        projects = state.projects.map(ProjectRecord.init)
        selectedProjectID = state.selectedProjectID
    }

    private enum CodingKeys: String, CodingKey {
        case freeRoomID, version, projects, selectedProjectID
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        guard (1...2).contains(version) else { throw ArchiveError.unsupportedVersion }
        freeRoomID = try values.decodeIfPresent(UUID.self, forKey: .freeRoomID)
        selectedProjectID = try values.decodeIfPresent(UUID.self, forKey: .selectedProjectID)
        projects = try values.decode([ProjectRecord].self, forKey: .projects)
        if version == 1 {
            for index in projects.indices {
                guard projects[index].rooms == nil, projects[index].storeys == nil,
                      projects[index].planningScope == nil,
                      projects[index].floors.allSatisfy({ $0.roomID == nil }),
                      projects[index].snapshots.allSatisfy({ $0.roomID == nil }) else {
                    throw MaterialInputError.invalid
                }
                projects[index].migrateRelationships()
            }
        }
        try validate()
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
        var planningScope: PlanningScope?
        var rooms: [ProjectRoom]?
        var storeys: [ProjectStorey]?
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
        var parts: [ModelPart]

        init(_ state: Workspace.Project.State) {
            id = state.id
            name = state.name
            scans = state.scans.map { ScanRecord(id: $0.id, label: $0.label, rooms: $0.rooms, roomPlanJSON: $0.roomPlanJSON, roomPlanStructure: $0.roomPlanStructure, sourceUsdz: $0.sourceUsdz, transform: $0.transform) }
            floors = state.floors.map(FloorRecord.init)
            selectedFloorIDs = state.selectedFloorIDs
            planningScope = state.planningScope
            rooms = state.rooms
            storeys = state.storeys
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
            parts = state.parts
        }

        private enum CodingKeys: String, CodingKey {
            case id, name, scans, floors, selectedFloorIDs, planningScope, rooms, storeys, splitAtM, splitAxis, geometryCorrections, undoneGeometryCorrectionIDs, scanPlacements, undoneScanPlacementIDs, floorVariants, undoneFloorVariantIDs, walls, utilities, furniture, parts
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            scans = try container.decode([ScanRecord].self, forKey: .scans)
            floors = try container.decode([FloorRecord].self, forKey: .floors)
            selectedFloorIDs = try container.decode([UUID].self, forKey: .selectedFloorIDs)
            planningScope = try container.decodeIfPresent(PlanningScope.self, forKey: .planningScope)
            rooms = try container.decodeIfPresent([ProjectRoom].self, forKey: .rooms)
            storeys = try container.decodeIfPresent([ProjectStorey].self, forKey: .storeys)
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
            parts = try container.decodeIfPresent([ModelPart].self, forKey: .parts) ?? []
        }

        var state: Workspace.Project.State {
            var state = Workspace.Project.State(id: id, name: name, scans: scans.map { .init(id: $0.id, label: $0.label, rooms: $0.rooms, roomPlanJSON: $0.roomPlanJSON, roomPlanStructure: $0.roomPlanStructure, sourceUsdz: $0.sourceUsdz, transform: $0.transform) },
                  floors: floors.map(\.state), selectedFloorIDs: selectedFloorIDs,
                  splitAtM: splitAtM, splitAxis: splitAxis, geometryCorrections: geometryCorrections,
                  undoneGeometryCorrectionIDs: undoneGeometryCorrectionIDs,
                  scanPlacements: scanPlacements, undoneScanPlacementIDs: undoneScanPlacementIDs,
                  floorVariants: floorVariants, undoneFloorVariantIDs: undoneFloorVariantIDs,
                  walls: walls, utilities: utilities, furniture: furniture, parts: parts,
                  rooms: rooms, storeys: storeys ?? [])
            state.planningScope = planningScope
            return state
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
        var storey: String?
        var roomID: UUID?
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
            storey = state.storey
            roomID = state.roomID
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
            state.storey = storey
            state.roomID = roomID ?? id
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
        return archive
    }

    public func save(_ archive: WorkspaceArchive) throws {
        try archive.validate()
        if FileManager.default.fileExists(atPath: url.path) { _ = try load() }
        let data = try JSONEncoder().encode(archive.version == 1 ? WorkspaceArchive(archive.state) : archive)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

extension WorkspaceArchive {
    func validate() throws {
        guard (1...2).contains(version) else { throw ArchiveError.unsupportedVersion }
        guard Set(projects.map(\.id)).count == projects.count,
              selectedProjectID == nil || projects.contains(where: { $0.id == selectedProjectID }) else {
            throw MaterialInputError.invalid
        }
        for project in projects {
            guard let rooms = project.rooms, let storeys = project.storeys,
                  Set(rooms.map(\.id)).count == rooms.count,
                  Set(storeys.map(\.id)).count == storeys.count,
                  rooms.allSatisfy({ room in room.storeyID == nil || storeys.contains { $0.id == room.storeyID } }),
                  project.floors.allSatisfy({ floor in rooms.contains { $0.id == floor.roomID } }),
                  project.snapshots.allSatisfy({ floor in rooms.contains { $0.id == floor.roomID } }) else {
                throw MaterialInputError.invalid
            }
            switch project.planningScope {
            case .room(let id):
                guard rooms.contains(where: { $0.id == id }) else { throw MaterialInputError.invalid }
            case .storey(let id):
                guard storeys.contains(where: { $0.id == id }) else { throw MaterialInputError.invalid }
            case .house, nil: break
            }
            for correction in project.geometryCorrections {
                guard !correction.before.isEmpty, !correction.after.isEmpty,
                      Set(correction.before.map(\.id)).count == correction.before.count,
                      Set(correction.after.map(\.id)).count == correction.after.count else { throw MaterialInputError.invalid }
            }
            for snapshot in project.snapshots {
                try validateRoom(outer: snapshot.room.outer.vertices, holes: snapshot.room.holes.map(\.vertices))
            }
            guard Set(project.floors.map(\.id)).count == project.floors.count,
                  Set(project.selectedFloorIDs).count == project.selectedFloorIDs.count,
                  Set(project.selectedFloorIDs).isSubset(of: Set(project.floors.map(\.id))),
                  Set(project.geometryCorrections.map(\.id)).count == project.geometryCorrections.count,
                  Set(project.floorVariants.map(\.id)).count == project.floorVariants.count,
                  Set(project.scans.map(\.id)).count == project.scans.count,
                  Set(project.scanPlacements.map(\.id)).count == project.scanPlacements.count,
                  project.scanPlacements.allSatisfy({ placement in project.scans.contains { $0.id == placement.scanID } }),
                  Set(project.undoneScanPlacementIDs).count == project.undoneScanPlacementIDs.count,
                  Set(project.undoneScanPlacementIDs).isSubset(of: Set(project.scanPlacements.map(\.id))),
                  Set(project.undoneGeometryCorrectionIDs).count == project.undoneGeometryCorrectionIDs.count,
                  Set(project.undoneGeometryCorrectionIDs).isSubset(of: Set(project.geometryCorrections.map(\.id))),
                  Set(project.undoneFloorVariantIDs).count == project.undoneFloorVariantIDs.count,
                  Set(project.undoneFloorVariantIDs).isSubset(of: Set(project.floorVariants.map(\.id))) else {
                throw MaterialInputError.invalid
            }
            let active = project.floorVariants.filter { $0.before != nil && !project.undoneFloorVariantIDs.contains($0.id) }
            guard active.count <= 1 else { throw MaterialInputError.invalid }
            for variant in project.floorVariants where variant.before != nil {
                guard let before = variant.before, let inputs = variant.inputs,
                      !variant.floorIDs.isEmpty,
                      Set(variant.floorIDs).count == variant.floorIDs.count,
                      Set(before.map(\.id)) == Set(variant.floorIDs),
                      before.count == variant.floorIDs.count,
                      inputs.count == before.count,
                      Set(inputs.map(\.id)) == Set(variant.floorIDs) else { throw MaterialInputError.invalid }
                if active.contains(where: { $0.id == variant.id }) {
                    guard Set(variant.floorIDs).isSubset(of: Set(project.floors.map(\.id))) else { throw MaterialInputError.invalid }
                }
                for snapshot in before + inputs {
                    try validateRoom(outer: snapshot.room.outer.vertices, holes: snapshot.room.holes.map(\.vertices))
                }
            }
            for floor in project.floors {
                try validateRoom(outer: floor.room.outer.vertices, holes: floor.room.holes.map(\.vertices))
            }
        }
    }
}

extension WorkspaceArchive.ProjectRecord {
    var snapshots: [FloorSnapshot] {
        geometryCorrections.flatMap { $0.before + $0.after } + floorVariants.flatMap { ($0.before ?? []) + ($0.inputs ?? []) }
    }

    mutating func migrateRelationships() {
        rooms = []
        storeys = []
        var membership: [UUID: UUID] = [:]
        for correction in geometryCorrections {
            if case .split = correction.operation, let original = correction.before.first {
                for floor in correction.after { membership[floor.id] = membership[original.id] ?? original.id }
            }
        }
        let normalize: (FloorSnapshot) -> FloorSnapshot = { snapshot in
            var snapshot = snapshot
            snapshot.roomID = membership[snapshot.id] ?? snapshot.id
            return snapshot
        }
        for floor in floors.map(\.state).map(FloorSnapshot.init) + snapshots {
            let roomID = membership[floor.id] ?? floor.id
            if rooms?.contains(where: { $0.id == roomID }) == false {
                rooms?.append(ProjectRoom(id: roomID, name: floor.name))
            }
        }
        for index in floors.indices { floors[index].roomID = membership[floors[index].id] ?? floors[index].id }
        geometryCorrections = geometryCorrections.map { correction in
            GeometryCorrection(id: correction.id, operation: correction.operation,
                               before: correction.before.map(normalize), after: correction.after.map(normalize))
        }
        for index in floorVariants.indices {
            floorVariants[index].before = floorVariants[index].before?.map(normalize)
            floorVariants[index].inputs = floorVariants[index].inputs?.map(normalize)
        }
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
