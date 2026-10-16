import ComposableArchitecture2
import Foundation
import PlnFlrLayout

/// A durable snapshot of a floor before or after a user-initiated geometry operation.
public struct FloorSnapshot: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let storey: String?
    public let room: Room
    public let thresholds: [Threshold]
    public let windows: [Opening]
    public let material: FloorMaterial
    public let packSize: String
    public let groutMm: String
    public let accessID: UUID
    public let expansionMm: String
    public let finish: FloorFinish
    public let plankLengthM: String
    public let plankWidthM: String

    public init(_ state: Workspace.Floor.State) {
        id = state.id
        name = state.name
        storey = state.storey
        room = state.room
        thresholds = state.thresholds
        windows = state.windows
        material = state.material
        packSize = state.packSize
        groutMm = state.groutMm
        accessID = state.accessID
        expansionMm = state.expansionMm
        finish = state.finish
        plankLengthM = state.plankLengthM
        plankWidthM = state.plankWidthM
    }

    public var state: Workspace.Floor.State {
        var state = Workspace.Floor.State(
            id: id,
            name: name,
            room: room,
            thresholds: thresholds,
            windows: windows,
            expansionMm: expansionMm,
            plankLengthM: plankLengthM,
            plankWidthM: plankWidthM,
            accessID: accessID
        )
        state.storey = storey
        state.material = material
        state.packSize = packSize
        state.groutMm = groutMm
        state.finish = finish
        return state
    }
}

/// Append-only record of a geometry operation; both sides remain available for audit or undo.
public struct GeometryCorrection: Codable, Equatable, Sendable, Identifiable {
    public enum Operation: Codable, Equatable, Sendable {
        case split(axis: SplitAxis, atMm: Int)
        case join
    }

    public let id: UUID
    public let operation: Operation
    public let before: [FloorSnapshot]
    public let after: [FloorSnapshot]

    public init(
        id: UUID,
        operation: Operation,
        before: [FloorSnapshot],
        after: [FloorSnapshot]
    ) {
        self.id = id
        self.operation = operation
        self.before = before
        self.after = after
    }

}

/// Manual placement of a preserved scan. Translation is integer millimetres; yaw is degrees. Identity is the default.
public struct ScanTransform: Codable, Equatable, Sendable {
    public static let identity = ScanTransform(xMm: 0, yMm: 0, zMm: 0, yawDegrees: 0)

    public var xMm: Int
    public var yMm: Int
    public var zMm: Int
    public var yawDegrees: Int

    public init(xMm: Int, yMm: Int, zMm: Int, yawDegrees: Int) {
        self.xMm = xMm
        self.yMm = yMm
        self.zMm = zMm
        self.yawDegrees = yawDegrees
    }
}

/// Sum of separate floor plans for one selection. Rooms are not unioned, so overlap is counted twice.
public struct FloorVariant: Codable, Equatable, Sendable, Identifiable {
    public static let sumLabel = "Suma osobnych planów podłogi"
    public let id: UUID
    public let floorIDs: [UUID]
    public let areaNetMm2: Int
    public let areaBoughtMm2: Int
    public let fullBoards: Int
    public let pieces: Int
    public let packs: Int?
    public var before: [FloorSnapshot]?
    public var inputs: [FloorSnapshot]?
    public var selectedFloorIDsBefore: [UUID]?

    public init(id: UUID, floorIDs: [UUID], areaNetMm2: Int, areaBoughtMm2: Int, fullBoards: Int, pieces: Int, packs: Int?) {
        self.id = id
        self.floorIDs = floorIDs
        self.areaNetMm2 = areaNetMm2
        self.areaBoughtMm2 = areaBoughtMm2
        self.fullBoards = fullBoards
        self.pieces = pieces
        self.packs = packs
    }
}

/// Append-only record of a manual scan placement; the previous transform remains available for undo.
public struct ScanPlacement: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public enum Provenance: String, Codable, Sendable {
        case manualCorrection

        public var label: String { "Ręczna korekta" }
    }

    public let scanID: UUID
    public let before: ScanTransform
    public let after: ScanTransform
    public let provenance: Provenance

    public init(id: UUID, scanID: UUID, before: ScanTransform, after: ScanTransform, provenance: Provenance = .manualCorrection) {
        self.id = id
        self.scanID = scanID
        self.before = before
        self.after = after
        self.provenance = provenance
    }

    private enum CodingKeys: String, CodingKey {
        case id, scanID, before, after, provenance
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        scanID = try values.decode(UUID.self, forKey: .scanID)
        before = try values.decode(ScanTransform.self, forKey: .before)
        after = try values.decode(ScanTransform.self, forKey: .after)
        provenance = try values.decodeIfPresent(Provenance.self, forKey: .provenance) ?? .manualCorrection
    }
}

public struct ModelPart: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var scanID: UUID
    public var nodePaths: [String]

    public init(id: UUID, name: String, scanID: UUID, nodePaths: [String]) {
        self.id = id
        self.name = name
        self.scanID = scanID
        self.nodePaths = nodePaths
    }
}

@Feature
public struct Workspace {
    public static let loadFailureMessage = "Nie udało się odczytać projektów. Plik pozostaje bez zmian. Spróbuj ponownie lub odzyskaj go z kopii zapasowej."
    @Feature
    public struct Scan {
        public struct State: Equatable, Identifiable, Sendable {
            public var id: UUID { scanID }
            public var label: String
            public var rooms: [CapturedRoom]
            public var scanID: UUID
            /// Full Apple CapturedRoom encoding, independent of derived floor geometry.
            public var roomPlanJSON: Data?

            public var roomPlanStructure: RoomPlanStructureSource?
            /// Original imported RoomPlan USDZ, preserved independently of derived room geometry.
            public var sourceUsdz: Data?
            /// Manual placement. Default is identity and never rewrites source bytes.
            public var transform: ScanTransform

            public init(
                id: UUID,
                label: String,
                rooms: [CapturedRoom],
                roomPlanJSON: Data? = nil,
                roomPlanStructure: RoomPlanStructureSource? = nil,
                sourceUsdz: Data? = nil,
                transform: ScanTransform = .identity
            ) {
                self.label = label
                self.rooms = rooms
                self.scanID = id
                self.roomPlanJSON = roomPlanJSON
                self.roomPlanStructure = roomPlanStructure
                self.sourceUsdz = sourceUsdz
                self.transform = transform
            }
        }

        public enum Action {
            case setManualPlacementButtonTapped(ScanTransform)
        }

        public init() {}

        public var body: some Feature {
            Update { _, _ in }
        }
    }

    @Feature
    public struct Floor {
        public struct State: Equatable, Identifiable, Sendable {
            public var material = FloorMaterial.plank
            public var packSize = "8"
            public var groutMm = "3"
            public var accessID: UUID
            public var error: String?
            public var expansionMm: String
            public var finish = FloorFinish.oak
            public var isShowing3DPreview = false
            public var floorID: UUID
            public var id: UUID { floorID }
            public var name: String
            public var storey: String?
            public var plan: LayoutPlan?
            public var plankLengthM: String
            public var plankWidthM: String
            public var room: Room
            public var thresholds: [Threshold]
            public var windows: [Opening]

            public init(
                id: UUID,
                name: String,
                room: Room,
                thresholds: [Threshold] = [],
                windows: [Opening] = [],
                expansionMm: String = "10",
                plankLengthM: String = "1.383",
                plankWidthM: String = "0.156",
                plan: LayoutPlan? = nil,
                error: String? = nil,
                accessID: UUID? = nil
            ) {
                self.accessID = accessID ?? id
                self.error = error
                self.expansionMm = expansionMm
                self.floorID = id
                self.name = name
                self.plan = plan
                self.plankLengthM = plankLengthM
                self.plankWidthM = plankWidthM
                self.room = room
                self.thresholds = thresholds
                self.windows = windows
            }
        }

        public init() {}

        public var body: some Feature {
            Update { _, _ in }
                .onChange(of: WorkspaceArchive.FloorRecord(store.state)) { state in
                    guard state.plan != nil else { return }
                    do {
                        state.plan = try state.makePlan()
                        state.error = nil
                    } catch {
                        state.plan = nil
                        state.error = error.localizedDescription
                    }
                }
        }
    }

    @Feature
    public struct Project {
        public struct State: Equatable, Identifiable, Sendable {
            public var error: String?
            public var floors: [Floor.State]
            public var geometryCorrections: [GeometryCorrection]
            public var undoneGeometryCorrectionIDs: [UUID]
            public var scanPlacements: [ScanPlacement]
            public var undoneScanPlacementIDs: [UUID]
            public var floorVariants: [FloorVariant]
            public var undoneFloorVariantIDs: [UUID]
            public var walls: [WallSegment]
            public var utilities: [UtilityRoute]
            public var furniture: [FurnitureItem]
            public var parts: [ModelPart]
            public var id: UUID { projectID }
            public var name: String
            public var projectID: UUID
            public var scans: [Scan.State]
            public var selectedFloorIDs: [UUID]
            public var splitAtM: String
            public var splitAxis: SplitAxis

            public init(
                id: UUID,
                name: String,
                scans: [Scan.State] = [],
                floors: [Floor.State] = [],
                selectedFloorIDs: [UUID] = [],
                splitAtM: String = "1.500",
                splitAxis: SplitAxis = .x,
                error: String? = nil,
                geometryCorrections: [GeometryCorrection] = [],
                undoneGeometryCorrectionIDs: [UUID] = [],
                scanPlacements: [ScanPlacement] = [],
                undoneScanPlacementIDs: [UUID] = [],
                floorVariants: [FloorVariant] = [],
                undoneFloorVariantIDs: [UUID] = [],
                walls: [WallSegment] = [],
                utilities: [UtilityRoute] = [],
                furniture: [FurnitureItem] = [],
                parts: [ModelPart] = []
            ) {
                self.error = error
                self.floors = floors
                self.geometryCorrections = geometryCorrections
                self.undoneGeometryCorrectionIDs = undoneGeometryCorrectionIDs
                self.scanPlacements = scanPlacements
                self.undoneScanPlacementIDs = undoneScanPlacementIDs
                self.floorVariants = floorVariants
                self.undoneFloorVariantIDs = undoneFloorVariantIDs
                self.walls = walls
                self.utilities = utilities
                self.furniture = furniture
                self.parts = parts
                self.name = name
                self.projectID = id
                self.scans = scans
                self.selectedFloorIDs = selectedFloorIDs
                self.splitAtM = splitAtM
                self.splitAxis = splitAxis
            }
        }

        public enum Action {
            case scans(Scan.State.ID, Scan.Action)
            case floors(Floor.State.ID, Floor.Action)
            case undoLastGeometryCorrectionButtonTapped
            case undoLastScanPlacementButtonTapped
            case undoLastFloorVariantButtonTapped
            case extractPart(UUID, String, [String])
            case detachPart(UUID)
            case undoLastPartButtonTapped
        }

        public init() {}

        public var body: some Feature {
            Update { state, action in
                guard case .undoLastGeometryCorrectionButtonTapped = action,
                      state.activeFloorVariant == nil,
                      let correction = state.geometryCorrections.last(where: {
                          !state.undoneGeometryCorrectionIDs.contains($0.id)
                      }),
                      correction.after.allSatisfy({ after in
                          state.floors.contains(where: { $0.id == after.id })
                      }) else { return }
                let resultIDs = Set(correction.after.map(\.id))
                state.floors.removeAll { resultIDs.contains($0.id) }
                state.floors.append(contentsOf: correction.before.map(\.state))
                state.undoneGeometryCorrectionIDs.append(correction.id)
                state.selectedFloorIDs = correction.before.map(\.id)
                state.error = nil
            }
            Update { state, action in
                switch action {
                case .extractPart(let scanID, let name, let paths):
                    do {
                        guard let scan = state.scans.first(where: { $0.id == scanID }) else {
                            throw HouseScene.PreviewError.missingSource
                        }
                        try HouseScene.validateSelection(scan, paths: paths)
                        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        state.parts.append(ModelPart(id: UUID(), name: label.isEmpty ? "Część modelu" : label,
                                                     scanID: scanID, nodePaths: Array(Set(paths)).sorted()))
                        state.error = nil
                    } catch {
                        state.error = error.localizedDescription
                    }
                case .detachPart(let id):
                    state.detachPart(id)
                case .undoLastPartButtonTapped:
                    if let id = state.parts.last?.id { state.detachPart(id) }
                case .scans:
                    break
                case .undoLastScanPlacementButtonTapped:
                    guard let placement = state.scanPlacements.last(where: {
                        !state.undoneScanPlacementIDs.contains($0.id)
                    }),
                          let index = state.scans.firstIndex(where: { $0.id == placement.scanID }),
                          state.scans[index].transform == placement.after else { return }
                    state.scans[index].transform = placement.before
                    state.undoneScanPlacementIDs.append(placement.id)
                    state.error = nil
                case .undoLastFloorVariantButtonTapped:
                    guard let variant = state.activeFloorVariant,
                          let before = variant.before else { return }
                    let ids = Set(variant.floorIDs)
                    guard ids == Set(before.map(\.id)),
                          ids.isSubset(of: Set(state.floors.map(\.id))) else { return }
                    for index in state.floors.indices {
                        if let snapshot = before.first(where: { $0.id == state.floors[index].id }) {
                            state.floors[index] = snapshot.state
                        }
                    }
                    state.selectedFloorIDs = variant.selectedFloorIDsBefore ?? before.map(\.id)
                    state.undoneFloorVariantIDs.append(variant.id)
                    state.error = nil
                default:
                    break
                }
            }
            .forEach(\.floors) {
                Floor()
            }
            .forEach(\.scans) {
                Scan()
            }
        }
    }

    public struct State {
        public var isCapturingRoom = false
        public var isPurchasing = false
        public var purchaseMessage: String?
        public var proProduct: ProProduct?
        public var freeRoomID: UUID?
        public var hasPro = false
        public var isPaywallPresented = false
        public var isAddingRoom = false
        public var manualName = "Pokój"
        public var manualWidthM = "4"
        public var manualHeightM = "3"
        public var manualRoomError: String?
        public var hasLoaded = false
        public var storageError: String?
        public var error: String?
        public var isImporting: Bool
        public var projects: [Project.State]
        public var selectedProjectID: UUID?

        public init(
            error: String? = nil,
            isImporting: Bool = false,
            projects: [Project.State] = [],
            selectedProjectID: UUID? = nil
        ) {
            self.error = error
            self.isImporting = isImporting
            self.projects = projects
            self.selectedProjectID = selectedProjectID
        }
    }

    public enum Action {
        case scanRoomButtonTapped
        case roomCaptureFinished(Data)
        case structureCaptureFinished(RoomPlanStructureSource)
        case roomCaptureCancelled
        case roomCaptureFailed(String)
        case buyProButtonTapped
        case purchaseFinished(PurchaseOutcome)
        case purchaseFailed(String)
        case restorePurchasesButtonTapped
        case restoreFinished(Bool)
        case storeStarted
        case refreshAccess
        case reloadProductButtonTapped
        case storeProductLoaded(ProProduct?)
        case addRoomButtonTapped
        case appStarted
        case importFailed(String)
        case createFloorVariantButtonTapped(UUID)
        case planFloorButtonTapped(UUID, UUID)
        case planSelectedFloorsButtonTapped(UUID)
        case proAccessChanged(Bool)
        case retrySaveButtonTapped
        case importUsdz(Data)
        case joinSelectedButtonTapped
        case newProjectButtonTapped
        case projects(Project.State.ID, Project.Action)
        case splitSelectedButtonTapped
    }

    @FeatureEnvironment(\.uuid) var uuid
    @FeatureEnvironment(\.workspaceFiles) var files
    @FeatureEnvironment(\.purchases) var purchases
    @FeatureState var isStoreStarted = false

    public init() {}

    public var body: some Feature {
        Update { state, action in
            if state.storageError != nil && !state.hasLoaded {
                switch action {
                case .scanRoomButtonTapped, .roomCaptureFinished, .structureCaptureFinished,
                     .addRoomButtonTapped, .importUsdz, .newProjectButtonTapped,
                     .joinSelectedButtonTapped, .splitSelectedButtonTapped,
                     .createFloorVariantButtonTapped, .planFloorButtonTapped, .planSelectedFloorsButtonTapped, .projects:
                    return
                default: break
                }
            }
            switch action {
            case .scanRoomButtonTapped:
                state.isCapturingRoom = true
                state.error = nil
            case .roomCaptureCancelled:
                state.isCapturingRoom = false
            case .roomCaptureFailed(let message):
                guard state.isCapturingRoom else { return }
                state.isCapturingRoom = false
                state.error = message
            case .roomCaptureFinished(let source):
                guard state.isCapturingRoom else { return }
                state.isCapturingRoom = false
                guard !source.isEmpty else {
                    state.error = "Skan jest pusty. Spróbuj ponownie."
                    return
                }
                if state.selectedProjectIndex == nil {
                    let project = Project.State(id: uuid(), name: "Projekt \(state.projects.count + 1)")
                    state.projects.append(project)
                    state.selectedProjectID = project.id
                }
                guard let index = state.selectedProjectIndex else { return }
                state.projects[index].scans.append(Scan.State(
                    id: uuid(), label: "Skan \(state.projects[index].scans.count + 1)",
                    rooms: [], roomPlanJSON: source
                ))
                state.error = nil
            case .structureCaptureFinished(let source):
                guard state.isCapturingRoom else { return }
                state.isCapturingRoom = false
                guard !source.rooms.isEmpty, source.rooms.allSatisfy({ !$0.isEmpty }), !source.structure.isEmpty else {
                    state.error = "Skan jest pusty. Spróbuj ponownie."
                    return
                }
                if state.selectedProjectIndex == nil {
                    let project = Project.State(id: uuid(), name: "Projekt \(state.projects.count + 1)")
                    state.projects.append(project)
                    state.selectedProjectID = project.id
                }
                guard let index = state.selectedProjectIndex else { return }
                state.projects[index].scans.append(Scan.State(
                    id: uuid(), label: "Skan \(state.projects[index].scans.count + 1)",
                    rooms: [], roomPlanStructure: source
                ))
                state.error = nil
            case .refreshAccess:
                let client = purchases
                store.addTask { try store.send(.proAccessChanged(await client.currentAccess())) }
            case .reloadProductButtonTapped:
                let client = purchases
                store.addTask {
                    do { try store.send(.storeProductLoaded(try await client.product())) }
                    catch { try store.send(.purchaseFailed(error.localizedDescription)) }
                }
            case .storeStarted:
                guard !isStoreStarted else { return }
                isStoreStarted = true
                let client = purchases
                let updates = client.updates()
                store.addTask {
                    for await hasPro in updates { try store.send(.proAccessChanged(hasPro)) }
                }
                store.addTask {
                    try store.send(.proAccessChanged(await client.currentAccess()))
                    do { try store.send(.storeProductLoaded(try await client.product())) }
                    catch { try store.send(.purchaseFailed(error.localizedDescription)) }
                }
            case .storeProductLoaded(let product):
                state.proProduct = product
            case .buyProButtonTapped:
                guard !state.isPurchasing else { return }
                state.isPurchasing = true
                state.purchaseMessage = nil
                let client = purchases
                store.addTask {
                    do { try store.send(.purchaseFinished(try await client.purchase())) }
                    catch { try store.send(.purchaseFailed(error.localizedDescription)) }
                }
            case .restorePurchasesButtonTapped:
                guard !state.isPurchasing else { return }
                state.isPurchasing = true
                state.purchaseMessage = nil
                let client = purchases
                store.addTask {
                    do { try store.send(.restoreFinished(try await client.restore())) }
                    catch { try store.send(.purchaseFailed(error.localizedDescription)) }
                }
            case .purchaseFinished(let outcome):
                state.isPurchasing = false
                switch outcome {
                case .purchased:
                    state.hasPro = true
                    state.isPaywallPresented = false
                case .pending:
                    state.purchaseMessage = "Zakup oczekuje na zatwierdzenie przez Apple."
                case .cancelled: break
                }
            case .purchaseFailed(let message):
                state.isPurchasing = false
                state.purchaseMessage = message
            case .restoreFinished(let hasPro):
                state.isPurchasing = false
                state.applyProAccess(hasPro)
                state.purchaseMessage = hasPro ? "Przywrócono PlnFlr Pro." : "Na tym koncie Apple nie znaleziono zakupu PlnFlr Pro."
            case .appStarted:
                guard !state.hasLoaded else { return }
                do {
                    let restored = try files.load().state
                    state.projects = restored.projects
                    state.selectedProjectID = restored.selectedProjectID
                    state.freeRoomID = restored.freeRoomID
                    state.refreshPlans()
                    state.storageError = nil
                    state.hasLoaded = true
                } catch {
                    state.storageError = Self.loadFailureMessage
                }
            case .retrySaveButtonTapped:
                guard state.hasLoaded else { return }
                save(&state)
            case .createFloorVariantButtonTapped(let projectID):
                guard let p = state.projects.firstIndex(where: { $0.id == projectID }),
                      state.projects[p].activeFloorVariant == nil else { return }
                do {
                    let floors = try state.projects[p].floorsForPlanning(state.projects[p].selectedFloorIDs)
                    guard state.canPlan(floors) else {
                        state.isPaywallPresented = true
                        return
                    }
                    let plans = try floors.map { try $0.makePlan() }
                    var variant = FloorVariant(
                        id: uuid(), floorIDs: floors.map(\.id),
                        areaNetMm2: plans.reduce(0) { $0 + $1.bom.areaNetMm2 },
                        areaBoughtMm2: plans.reduce(0) { $0 + $1.bom.areaBoughtMm2 },
                        fullBoards: plans.reduce(0) { $0 + $1.bom.fullBoards },
                        pieces: plans.reduce(0) { $0 + $1.bom.pieces }, packs: nil
                    )
                    variant.before = floors.map(FloorSnapshot.init)
                    variant.inputs = variant.before
                    variant.selectedFloorIDsBefore = state.projects[p].selectedFloorIDs
                    state.projects[p].floorVariants.append(variant)
                    state.commitPlans(plans, floors: floors, projectIndex: p)
                } catch {
                    state.projects[p].error = error.localizedDescription
                }
            case .planFloorButtonTapped(let projectID, let floorID):
                state.planFloors([floorID], projectID: projectID)
            case .planSelectedFloorsButtonTapped(let projectID):
                guard let project = state.projects.first(where: { $0.id == projectID }) else { return }
                state.planFloors(project.selectedFloorIDs, projectID: projectID)
            case .proAccessChanged(let hasPro):
                state.applyProAccess(hasPro)
            case .importFailed(let message):
                state.error = message
            case .addRoomButtonTapped:
                do {
                    let width = try metresToMm(state.manualWidthM)
                    let height = try metresToMm(state.manualHeightM)
                    guard (100...100_000).contains(width), (100...100_000).contains(height) else {
                        throw ManualRoomError.invalidDimensions
                    }
                    let room = try rectangle(widthMm: width, heightMm: height)
                    if state.selectedProjectIndex == nil {
                        let project = Project.State(id: uuid(), name: "Projekt \(state.projects.count + 1)")
                        state.projects.append(project)
                        state.selectedProjectID = project.id
                    }
                    guard let index = state.selectedProjectIndex else { return }
                    let name = state.manualName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let floor = Floor.State(id: uuid(), name: name.isEmpty ? "Pokój" : name, room: room)
                    state.projects[index].floors.append(floor)
                    state.projects[index].selectedFloorIDs = [floor.id]
                    state.manualRoomError = nil
                    state.isAddingRoom = false
                    state.error = nil
                } catch {
                    state.manualRoomError = "Wymiary pokoju muszą wynosić od 0,1 do 100 m."
                }
            case .newProjectButtonTapped:
                let project = Project.State(
                    id: uuid(),
                    name: "Projekt \(state.projects.count + 1)"
                )
                state.projects.append(project)
                state.selectedProjectID = project.projectID
                state.error = nil
            case .importUsdz(let payload):
                do {
                    let captured: CapturedScan
                    do {
                        captured = try roomFromUsdz(payload)
                    } catch let error as ScanError where error == .notRoomPlan || error == .missingFloor || error == .notZip {
                        guard HouseScene.mesh(bytes: payload, transform: .identity) != nil else { throw error }
                        captured = CapturedScan(rooms: [])
                    }
                    if state.selectedProjectIndex == nil {
                        let project = Project.State(
                            id: uuid(),
                            name: "Projekt \(state.projects.count + 1)"
                        )
                        state.projects.append(project)
                        state.selectedProjectID = project.projectID
                    }
                    guard let index = state.selectedProjectIndex else { return }
                    let scan = Scan.State(
                        id: uuid(),
                        label: "Skan \(state.projects[index].scans.count + 1)",
                        rooms: captured.rooms,
                        sourceUsdz: payload
                    )
                    state.projects[index].scans.append(scan)
                    var floorIDs: [UUID] = []
                    for capturedRoom in captured.rooms {
                        let floor = Floor.State(
                            id: uuid(),
                            name: capturedRoom.name,
                            room: capturedRoom.room,
                            thresholds: capturedRoom.thresholds,
                            windows: capturedRoom.windows
                        )
                        floorIDs.append(floor.floorID)
                        state.projects[index].floors.append(floor)
                    }
                    if let first = floorIDs.first {
                        state.projects[index].selectedFloorIDs = [first]
                    }
                    state.projects[index].error = nil
                    state.error = nil
                } catch {
                    state.error = error.localizedDescription
                }
            case .splitSelectedButtonTapped:
                guard let index = state.selectedProjectIndex,
                      state.projects[index].activeFloorVariant == nil else { return }
                let selectedIDs = state.projects[index].selectedFloorIDs
                guard selectedIDs.count == 1,
                      let floorIndex = state.projects[index].floors.firstIndex(where: { $0.floorID == selectedIDs[0] })
                else { return }
                do {
                    let original = state.projects[index].floors[floorIndex]
                    let atMm = try metresToMm(state.projects[index].splitAtM)
                    let (left, right) = try splitRoom(
                        original.room,
                        axis: state.projects[index].splitAxis,
                        atMm: atMm
                    )
                    guard let left, let right else {
                        state.projects[index].error = LayoutError.splitLeavesNoArea.errorDescription
                        return
                    }
                    var first = Floor.State(
                        id: uuid(),
                        name: "\(original.name) A",
                        room: left,
                        thresholds: original.thresholds,
                        windows: original.windows,
                        expansionMm: original.expansionMm,
                        plankLengthM: original.plankLengthM,
                        plankWidthM: original.plankWidthM,
                        accessID: original.accessID
                    )
                    var second = Floor.State(
                        id: uuid(),
                        name: "\(original.name) B",
                        room: right,
                        thresholds: original.thresholds,
                        windows: original.windows,
                        expansionMm: original.expansionMm,
                        plankLengthM: original.plankLengthM,
                        plankWidthM: original.plankWidthM,
                        accessID: original.accessID
                    )
                    first.copyMaterial(from: original)
                    second.copyMaterial(from: original)
                    first.storey = original.storey
                    second.storey = original.storey
                    let correction = GeometryCorrection(
                        id: uuid(),
                        operation: .split(axis: state.projects[index].splitAxis, atMm: atMm),
                        before: [FloorSnapshot(original)],
                        after: [FloorSnapshot(first), FloorSnapshot(second)]
                    )
                    state.projects[index].floors.replaceSubrange(floorIndex...floorIndex, with: [first, second])
                    state.projects[index].geometryCorrections.append(correction)
                    state.projects[index].selectedFloorIDs = [first.floorID]
                    state.projects[index].error = nil
                } catch {
                    state.projects[index].error = error.localizedDescription
                }
            case .joinSelectedButtonTapped:
                guard let index = state.selectedProjectIndex,
                      state.projects[index].activeFloorVariant == nil else { return }
                let selectedIDs = state.projects[index].selectedFloorIDs
                let selected = state.projects[index].floors.filter { selectedIDs.contains($0.floorID) }
                guard selected.count == 2 else { return }
                do {
                    let joined = try joinRooms(selected[0].room, selected[1].room)
                    let inputs = selected.map(FloorSnapshot.init)
                    var item = Floor.State(
                        id: uuid(),
                        name: selected[0].name,
                        room: joined,
                        thresholds: selected[0].thresholds + selected[1].thresholds,
                        windows: selected[0].windows + selected[1].windows,
                        expansionMm: selected[0].expansionMm,
                        plankLengthM: selected[0].plankLengthM,
                        plankWidthM: selected[0].plankWidthM,
                        accessID: selected[0].accessID == selected[1].accessID ? selected[0].accessID : nil
                    )
                    item.copyMaterial(from: selected[0])
                    item.storey = selected[0].storey == selected[1].storey ? selected[0].storey : nil
                    let correction = GeometryCorrection(
                        id: uuid(),
                        operation: .join,
                        before: inputs,
                        after: [FloorSnapshot(item)]
                    )
                    state.projects[index].floors.removeAll { selectedIDs.contains($0.floorID) }
                    state.projects[index].floors.append(item)
                    state.projects[index].geometryCorrections.append(correction)
                    state.projects[index].selectedFloorIDs = [item.floorID]
                    state.projects[index].error = nil
                } catch {
                    state.projects[index].error = error.localizedDescription
                }
            case .projects(let projectID, .scans(let scanID, .setManualPlacementButtonTapped(let transform))):
                guard let project = state.projects.firstIndex(where: { $0.id == projectID }),
                      let index = state.projects[project].scans.firstIndex(where: { $0.id == scanID }) else { return }
                let before = state.projects[project].scans[index].transform
                guard before != transform else { return }
                let placement = ScanPlacement(id: uuid(), scanID: scanID, before: before, after: transform)
                state.projects[project].scans[index].transform = transform
                state.projects[project].scanPlacements.append(placement)
                state.projects[project].error = nil
            case .projects:
                break
            }
        }
        .forEach(\.projects) {
            Project()
        }
        .onChange(of: store.projects.map { $0.floors.map(WorkspaceArchive.FloorRecord.init) }) { state in
            state.refreshPlans()
        }
        .onChange(of: WorkspaceArchive(store.state)) { state in
            guard state.hasLoaded else { return }
            save(&state)
        }
    }

    private func save(_ state: inout State) {
        do {
            try files.save(WorkspaceArchive(state))
            state.storageError = nil
        } catch {
            state.storageError = "Nie udało się zapisać projektów: \(error.localizedDescription)"
        }
    }
}

extension Workspace.Project.State {
    mutating func detachPart(_ id: UUID) {
        parts.removeAll { $0.id == id }
        error = nil
    }
}

extension Workspace.State {
    mutating func applyProAccess(_ value: Bool) {
        hasPro = value
        if value { isPaywallPresented = false }
        refreshPlans()
    }

    var selectedProjectIndex: Int? {
        guard let selectedProjectID else { return nil }
        return projects.firstIndex(where: { $0.projectID == selectedProjectID })
    }
}
