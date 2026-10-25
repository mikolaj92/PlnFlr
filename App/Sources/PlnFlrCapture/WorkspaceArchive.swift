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
        projects = try values.decode([ProjectRecord].self, forKey: .projects)
        if version == 1 {
            for index in projects.indices {
                guard projects[index].rooms == nil, projects[index].storeys == nil,
                      projects[index].projectScope == nil,
                      projects[index].floors.allSatisfy({ $0.roomID == nil }),
                      projects[index].snapshots.allSatisfy({ $0.roomID == nil }) else {
                    throw MaterialInputError.invalid
                }
                var seen = Set<UUID>()
                projects[index].rooms = (projects[index].floors.map { ($0.id, $0.name) }
                    + projects[index].snapshots.map { ($0.id, $0.name) }).compactMap { id, name in
                        seen.insert(id).inserted ? ProjectRoom(id: id, name: name) : nil
                    }
                projects[index].storeys = []
                projects[index].geometryCorrections = projects[index].geometryCorrections.map {
                    GeometryCorrection(id: $0.id, operation: $0.operation,
                                       before: $0.before.map { FloorSnapshot($0.state) },
                                       after: $0.after.map { FloorSnapshot($0.state) })
                }
                for variant in projects[index].floorVariants.indices {
                    projects[index].floorVariants[variant].before = projects[index].floorVariants[variant].before?.map { FloorSnapshot($0.state) }
                    projects[index].floorVariants[variant].inputs = projects[index].floorVariants[variant].inputs?.map { FloorSnapshot($0.state) }
                }
                for floor in projects[index].floors.indices {
                    projects[index].floors[floor].roomID = projects[index].floors[floor].id
                }
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
        var projectScope: ProjectScope?

        var snapshots: [FloorSnapshot] {
            geometryCorrections.flatMap { $0.before + $0.after }
                + floorVariants.flatMap { ($0.before ?? []) + ($0.inputs ?? []) }
        }
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
            projectScope = state.projectScope
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
            case id, name, scans, floors, selectedFloorIDs, planningScope, rooms, storeys, projectScope, splitAtM, splitAxis, geometryCorrections, undoneGeometryCorrectionIDs, scanPlacements, undoneScanPlacementIDs, floorVariants, undoneFloorVariantIDs, walls, utilities, furniture, parts
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
            projectScope = try container.decodeIfPresent(ProjectScope.self, forKey: .projectScope)
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
                  rooms: rooms, storeys: storeys ?? [], projectScope: projectScope)
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
        var current = archive
        current.version = 2
        let data = try JSONEncoder().encode(current)
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
            guard version != 1 || (project.projectScope == nil && project.storeys?.isEmpty == true),
                  let rooms = project.rooms, let storeys = project.storeys,
                  Set(rooms.map(\.id)).count == rooms.count,
                  Set(storeys.map(\.id)).count == storeys.count,
                  Set(project.scans.map(\.id)).count == project.scans.count,
                  Set(project.geometryCorrections.map(\.id)).count == project.geometryCorrections.count,
                  Set(project.floorVariants.map(\.id)).count == project.floorVariants.count else {
                throw MaterialInputError.invalid
            }
            for (ids, available) in [
                (project.selectedFloorIDs, project.floors.map(\.id)),
                (project.undoneGeometryCorrectionIDs, project.geometryCorrections.map(\.id)),
                (project.undoneFloorVariantIDs, project.floorVariants.map(\.id)),
                (project.undoneScanPlacementIDs, project.scanPlacements.map(\.id))
            ] {
                guard Set(ids).count == ids.count, Set(ids).isSubset(of: Set(available)) else {
                    throw MaterialInputError.invalid
                }
            }
            guard Set(project.scanPlacements.map(\.id)).count == project.scanPlacements.count,
                  project.scanPlacements.allSatisfy({ placement in
                      project.scans.contains { $0.id == placement.scanID }
                  }) else { throw MaterialInputError.invalid }
            let roomIDs = Set(rooms.map(\.id))
            let storeyIDs = Set(storeys.map(\.id))
            guard rooms.allSatisfy({ $0.storeyID == nil || storeyIDs.contains($0.storeyID!) }),
                  project.floors.allSatisfy({ $0.roomID.map(roomIDs.contains) == true }),
                  project.snapshots.allSatisfy({ $0.roomID.map(roomIDs.contains) == true }) else { throw MaterialInputError.invalid }
            switch project.projectScope {
            case .room(let id): guard roomIDs.contains(id) else { throw MaterialInputError.invalid }
            case .storey(let id): guard storeyIDs.contains(id) else { throw MaterialInputError.invalid }
            case .house, nil: break
            }
            for correction in project.geometryCorrections {
                guard !correction.before.isEmpty, !correction.after.isEmpty,
                      Set(correction.before.map(\.id)).count == correction.before.count,
                      Set(correction.after.map(\.id)).count == correction.after.count else {
                    throw MaterialInputError.invalid
                }
            }
            for snapshot in project.snapshots {
                try validateRoom(outer: snapshot.room.outer.vertices, holes: snapshot.room.holes.map(\.vertices))
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
