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

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        guard (1...2).contains(version) else { throw ArchiveError.unsupportedVersion }
        freeRoomID = try values.decodeIfPresent(UUID.self, forKey: .freeRoomID)
        selectedProjectID = try values.decodeIfPresent(UUID.self, forKey: .selectedProjectID)
        var records = try values.nestedUnkeyedContainer(forKey: .projects)
        projects = []
        while !records.isAtEnd {
            projects.append(try ProjectRecord(from: records.superDecoder(), version: version))
        }
        try validate()
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(version == 1 ? 2 : version, forKey: .version)
        try values.encodeIfPresent(freeRoomID, forKey: .freeRoomID)
        try values.encodeIfPresent(selectedProjectID, forKey: .selectedProjectID)
        try values.encode(projects, forKey: .projects)
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
        var parts: [ModelPart]
        var rooms: [ProjectRoom]
        var storeys: [ProjectStorey]
        var planningScope: PlanningScope?

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
            parts = state.parts
            rooms = state.rooms
            storeys = state.storeys
            planningScope = state.planningScope
        }

        private enum CodingKeys: String, CodingKey {
            case rooms, storeys, planningScope, id, name, scans, floors, selectedFloorIDs, splitAtM, splitAxis, geometryCorrections, undoneGeometryCorrectionIDs, scanPlacements, undoneScanPlacementIDs, floorVariants, undoneFloorVariantIDs, walls, utilities, furniture, parts
        }

        public func encode(to encoder: any Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(id, forKey: .id)
            try values.encode(name, forKey: .name)
            try values.encode(scans, forKey: .scans)
            try values.encode(floors, forKey: .floors)
            try values.encode(selectedFloorIDs, forKey: .selectedFloorIDs)
            try values.encode(splitAtM, forKey: .splitAtM)
            try values.encode(splitAxis, forKey: .splitAxis)
            try values.encode(geometryCorrections, forKey: .geometryCorrections)
            try values.encode(undoneGeometryCorrectionIDs, forKey: .undoneGeometryCorrectionIDs)
            try values.encode(scanPlacements, forKey: .scanPlacements)
            try values.encode(undoneScanPlacementIDs, forKey: .undoneScanPlacementIDs)
            try values.encode(floorVariants, forKey: .floorVariants)
            try values.encode(undoneFloorVariantIDs, forKey: .undoneFloorVariantIDs)
            try values.encode(walls, forKey: .walls)
            try values.encode(utilities, forKey: .utilities)
            try values.encode(furniture, forKey: .furniture)
            try values.encode(parts, forKey: .parts)
            try values.encode(rooms, forKey: .rooms)
            try values.encode(storeys, forKey: .storeys)
            try values.encode(planningScope, forKey: .planningScope)
        }

        public init(from decoder: Decoder) throws {
            try self.init(from: decoder, version: 2)
        }

        init(from decoder: Decoder, version: Int) throws {
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
            parts = try container.decodeIfPresent([ModelPart].self, forKey: .parts) ?? []
            if version == 2 {
                rooms = try container.decode([ProjectRoom].self, forKey: .rooms)
                storeys = try container.decode([ProjectStorey].self, forKey: .storeys)
                guard container.contains(.planningScope) else { throw MaterialInputError.invalid }
                planningScope = try container.decodeIfPresent(PlanningScope.self, forKey: .planningScope)
            } else {
                guard !container.contains(.rooms), !container.contains(.storeys),
                      !container.contains(.planningScope), floors.allSatisfy({ $0.roomID == nil }),
                      geometryCorrections.allSatisfy({ correction in
                          correction.before.allSatisfy { $0.roomID == nil }
                              && correction.after.allSatisfy { $0.roomID == nil }
                      }),
                      floorVariants.allSatisfy({ variant in
                          (variant.before ?? []).allSatisfy { $0.roomID == nil }
                              && (variant.inputs ?? []).allSatisfy { $0.roomID == nil }
                      }) else {
                    throw MaterialInputError.invalid
                }
                rooms = []
                storeys = []
                planningScope = nil
                for index in floors.indices { floors[index].roomID = floors[index].accessID }
                func migrated(_ snapshots: [FloorSnapshot]) -> [FloorSnapshot] {
                    snapshots.map { snapshot in
                        var snapshot = snapshot
                        snapshot.roomID = snapshot.accessID
                        return snapshot
                    }
                }
                geometryCorrections = geometryCorrections.map {
                    GeometryCorrection(id: $0.id, operation: $0.operation, before: migrated($0.before), after: migrated($0.after))
                }
                for index in floorVariants.indices {
                    floorVariants[index].before = floorVariants[index].before.map(migrated)
                    floorVariants[index].inputs = floorVariants[index].inputs.map(migrated)
                }
                let snapshots = floors.map { FloorSnapshot($0.state) } + geometryCorrections.flatMap { $0.before + $0.after } + floorVariants.flatMap { ($0.before ?? []) + ($0.inputs ?? []) }
                for snapshot in snapshots where !rooms.contains(where: { $0.id == snapshot.roomID }) {
                    rooms.append(ProjectRoom(id: snapshot.roomID!, name: snapshot.name))
                }
            }
        }

        var state: Workspace.Project.State {
            .init(id: id, name: name, scans: scans.map { .init(id: $0.id, label: $0.label, rooms: $0.rooms, roomPlanJSON: $0.roomPlanJSON, roomPlanStructure: $0.roomPlanStructure, sourceUsdz: $0.sourceUsdz, transform: $0.transform) },
                  floors: floors.map(\.state), selectedFloorIDs: selectedFloorIDs,
                  splitAtM: splitAtM, splitAxis: splitAxis, geometryCorrections: geometryCorrections,
                  undoneGeometryCorrectionIDs: undoneGeometryCorrectionIDs,
                  scanPlacements: scanPlacements, undoneScanPlacementIDs: undoneScanPlacementIDs,
                  floorVariants: floorVariants, undoneFloorVariantIDs: undoneFloorVariantIDs,
                  walls: walls, utilities: utilities, furniture: furniture, parts: parts,
                  rooms: rooms, storeys: storeys, planningScope: planningScope)
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
        var roomID: UUID?
        var material: FloorMaterial
        var packSize: String
        var groutMm: String
        var accessID: UUID
        var id: UUID
        var name: String
        var storey: String?
        var room: Room
        var thresholds: [Threshold]
        var windows: [Opening]
        var expansionMm: String
        var finish: FloorFinish?
        var plankLengthM: String
        var plankWidthM: String

        init(_ state: Workspace.Floor.State) {
            roomID = state.roomID
            material = state.material
            packSize = state.packSize
            groutMm = state.groutMm
            accessID = state.accessID
            id = state.id
            name = state.name
            storey = state.storey
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
            state.roomID = roomID ?? accessID
            state.storey = storey
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
        try archive.validate()
        return archive
    }

    public func save(_ archive: WorkspaceArchive) throws {
        if (1...2).contains(archive.version) { try archive.validate() }
        let data = try JSONEncoder().encode(archive)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

extension WorkspaceArchive {
    func validate() throws {
        guard (1...2).contains(version) else { throw ArchiveError.unsupportedVersion }
        guard Set(projects.map(\.id)).count == projects.count else { throw MaterialInputError.invalid }
        for project in projects {
            let roomIDs = Set(project.rooms.map(\.id))
            let storeyIDs = Set(project.storeys.map(\.id))
            guard roomIDs.count == project.rooms.count, storeyIDs.count == project.storeys.count,
                  project.rooms.allSatisfy({ $0.storeyID.map(storeyIDs.contains) ?? true }),
                  project.floors.allSatisfy({ $0.roomID.map(roomIDs.contains) ?? false }) else { throw MaterialInputError.invalid }
            switch project.planningScope {
            case .room(let id): guard roomIDs.contains(id) else { throw MaterialInputError.invalid }
            case .storey(let id): guard storeyIDs.contains(id) else { throw MaterialInputError.invalid }
            case .house, nil: break
            }
            let groups = project.geometryCorrections.flatMap { [$0.before, $0.after] } + project.floorVariants.flatMap { [$0.before ?? [], $0.inputs ?? []] }
            guard Set(project.geometryCorrections.map(\.id)).count == project.geometryCorrections.count,
                  Set(project.floorVariants.map(\.id)).count == project.floorVariants.count else { throw MaterialInputError.invalid }
            for snapshots in groups {
                guard Set(snapshots.map(\.id)).count == snapshots.count,
                      snapshots.allSatisfy({ $0.roomID.map(roomIDs.contains) ?? false }) else { throw MaterialInputError.invalid }
                for snapshot in snapshots {
                    try validateRoom(outer: snapshot.room.outer.vertices, holes: snapshot.room.holes.map(\.vertices))
                }
            }
            guard Set(project.floors.map(\.id)).count == project.floors.count else { throw MaterialInputError.invalid }
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
