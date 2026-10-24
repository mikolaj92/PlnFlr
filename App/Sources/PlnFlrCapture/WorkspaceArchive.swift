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
        var rooms: [ProjectRoom]
        var storeys: [Storey]
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
            try self.init(from: decoder, version: 2)
        }

        init(from decoder: any Decoder, version: Int) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            scans = try container.decode([ScanRecord].self, forKey: .scans)
            floors = try container.decode([FloorRecord].self, forKey: .floors)
            selectedFloorIDs = try container.decode([UUID].self, forKey: .selectedFloorIDs)
            if version == 1 {
                guard !container.contains(.rooms), !container.contains(.storeys),
                      !container.contains(.planningScope) else { throw MaterialInputError.invalid }
                planningScope = nil
                rooms = []
                storeys = []
            } else {
                planningScope = try container.decodeIfPresent(PlanningScope.self, forKey: .planningScope)
                rooms = try container.decode([ProjectRoom].self, forKey: .rooms)
                storeys = try container.decode([Storey].self, forKey: .storeys)
            }
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
            if version == 1 {
                guard floors.allSatisfy({ $0.roomID == nil }),
                      snapshots.allSatisfy({ $0.roomID == nil }) else { throw MaterialInputError.invalid }
                for floor in floors {
                    if !rooms.contains(where: { $0.id == floor.id }) {
                        rooms.append(ProjectRoom(id: floor.id, name: floor.name))
                    }
                }
                for snapshot in snapshots where !rooms.contains(where: { $0.id == snapshot.id }) {
                    rooms.append(ProjectRoom(id: snapshot.id, name: snapshot.name))
                }
                for index in floors.indices { floors[index].roomID = floors[index].id }
                geometryCorrections = geometryCorrections.map {
                    GeometryCorrection(id: $0.id, operation: $0.operation,
                                       before: $0.before.map { FloorSnapshot($0.state) },
                                       after: $0.after.map { FloorSnapshot($0.state) })
                }
                for index in floorVariants.indices {
                    floorVariants[index].before = floorVariants[index].before?.map { FloorSnapshot($0.state) }
                    floorVariants[index].inputs = floorVariants[index].inputs?.map { FloorSnapshot($0.state) }
                }
            }
        }

        var snapshots: [FloorSnapshot] {
            geometryCorrections.flatMap { $0.before + $0.after }
                + floorVariants.flatMap { ($0.before ?? []) + ($0.inputs ?? []) }
        }

        var state: Workspace.Project.State {
            var state = Workspace.Project.State(id: id, name: name, scans: scans.map { .init(id: $0.id, label: $0.label, rooms: $0.rooms, roomPlanJSON: $0.roomPlanJSON, roomPlanStructure: $0.roomPlanStructure, sourceUsdz: $0.sourceUsdz, transform: $0.transform) },
                  floors: floors.map(\.state), selectedFloorIDs: selectedFloorIDs,
                  splitAtM: splitAtM, splitAxis: splitAxis, geometryCorrections: geometryCorrections,
                  undoneGeometryCorrectionIDs: undoneGeometryCorrectionIDs,
                  scanPlacements: scanPlacements, undoneScanPlacementIDs: undoneScanPlacementIDs,
                  floorVariants: floorVariants, undoneFloorVariantIDs: undoneFloorVariantIDs,
                  walls: walls, utilities: utilities, furniture: furniture, parts: parts,
                  rooms: rooms, storeys: storeys)
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
        guard Set(projects.map(\.id)).count == projects.count,
              selectedProjectID == nil || projects.contains(where: { $0.id == selectedProjectID }) else {
            throw MaterialInputError.invalid
        }
        for project in projects {
            let roomIDs = Set(project.rooms.map(\.id))
            let storeyIDs = Set(project.storeys.map(\.id))
            guard roomIDs.count == project.rooms.count, storeyIDs.count == project.storeys.count,
                  project.rooms.allSatisfy({ $0.storeyID == nil || storeyIDs.contains($0.storeyID!) }),
                  project.floors.allSatisfy({ $0.roomID.map(roomIDs.contains) == true }),
                  project.snapshots.allSatisfy({ $0.roomID.map(roomIDs.contains) == true }),
                  Set(project.selectedFloorIDs).count == project.selectedFloorIDs.count,
                  Set(project.selectedFloorIDs).isSubset(of: Set(project.floors.map(\.id))),
                  Set(project.geometryCorrections.map(\.id)).count == project.geometryCorrections.count,
                  Set(project.floorVariants.map(\.id)).count == project.floorVariants.count,
                  Set(project.undoneGeometryCorrectionIDs).count == project.undoneGeometryCorrectionIDs.count,
                  Set(project.undoneGeometryCorrectionIDs).isSubset(of: Set(project.geometryCorrections.map(\.id))),
                  Set(project.undoneFloorVariantIDs).count == project.undoneFloorVariantIDs.count,
                  Set(project.undoneFloorVariantIDs).isSubset(of: Set(project.floorVariants.map(\.id))) else {
                throw MaterialInputError.invalid
            }
            if let scope = project.planningScope {
                switch scope {
                case .room(let id): guard roomIDs.contains(id) else { throw MaterialInputError.invalid }
                case .storey(let id): guard storeyIDs.contains(id) else { throw MaterialInputError.invalid }
                case .house: break
                }
            }
            for correction in project.geometryCorrections {
                guard !correction.before.isEmpty, !correction.after.isEmpty,
                      Set(correction.before.map(\.id)).count == correction.before.count,
                      Set(correction.after.map(\.id)).count == correction.after.count else {
                    throw MaterialInputError.invalid
                }
            }
            var memberships: [UUID: UUID] = [:]
            for snapshot in project.floors.map({ FloorSnapshot($0.state) }) + project.snapshots {
                guard let roomID = snapshot.roomID,
                      memberships[snapshot.id] == nil || memberships[snapshot.id] == roomID else {
                    throw MaterialInputError.invalid
                }
                memberships[snapshot.id] = roomID
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
