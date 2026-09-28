import ComposableArchitecture2
import CustomDump
import Foundation
import ModelIO
import PlnFlrLayout
import Testing
@testable import PlnFlrCapture

@Test func manualScanTransformPersistsAndUndoKeepsSourceBytes() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = WorkspaceStorage(url: directory.appendingPathComponent("workspace.json"))
    let sourceUsdz = twoFloorUsdz()
    let structure = Data("room-plan-structure".utf8)
    let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    let scanID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    let scan = Workspace.Scan.State(
        id: scanID,
        label: "Skan źródłowy",
        rooms: [],
        roomPlanStructure: RoomPlanStructureSource(rooms: [structure], structure: structure),
        sourceUsdz: sourceUsdz
    )
    var state = Workspace.State(
        projects: [.init(id: projectID, name: "Dom", scans: [scan])],
        selectedProjectID: projectID
    )
    state.hasLoaded = true
    let store = await TestStoreActor(initialState: state) {
        Workspace().environment(\.workspaceFiles, WorkspaceFiles(load: { try storage.load() }, save: { try storage.save($0) }))
    }
    let placed = ScanTransform(xMm: 1200, yMm: -40, zMm: 300, yawDegrees: 90)
    let placementID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    await store.send(.projects(projectID, .scans(scanID, .setManualPlacementButtonTapped(placed)))) {
        $0.projects[0].scans[0].transform = placed
        $0.projects[0].scanPlacements = [
            ScanPlacement(id: placementID, scanID: scanID, before: ScanTransform.identity, after: placed)
        ]
    }

    let restored = try storage.load()
    #expect(restored.version == 1)
    #expect(restored.state.projects[0].scans[0].transform == placed)
    #expect(restored.state.projects[0].scans[0].sourceUsdz == sourceUsdz)
    #expect(restored.state.projects[0].scans[0].roomPlanStructure?.structure == structure)

    let legacy = Data("""
    {
      "version": 1,
      "projects": [{
        "id": "00000000-0000-0000-0000-000000000010",
        "name": "Dom",
        "scans": [{
          "id": "00000000-0000-0000-0000-000000000011",
          "label": "Skan źródłowy",
          "rooms": []
        }],
        "floors": [],
        "selectedFloorIDs": [],
        "splitAtM": "1.500",
        "splitAxis": "x"
      }]
    }
    """.utf8)
    let decoded = try JSONDecoder().decode(WorkspaceArchive.self, from: legacy)
    #expect(decoded.version == 1)
    #expect(decoded.state.projects[0].scans[0].transform == ScanTransform.identity)
    #expect(decoded.state.projects[0].scanPlacements.isEmpty)

    await store.send(.projects(projectID, .undoLastScanPlacementButtonTapped)) {
        $0.projects[0].scans[0].transform = ScanTransform.identity
        $0.projects[0].undoneScanPlacementIDs = [placementID]
    }
    let afterUndo = try storage.load().state.projects[0]
    #expect(afterUndo.scans[0].transform == ScanTransform.identity)
    #expect(afterUndo.scans[0].sourceUsdz == sourceUsdz)
    #expect(afterUndo.scans[0].roomPlanStructure?.structure == structure)
    #expect(afterUndo.scanPlacements.count == 1)
    #expect(afterUndo.undoneScanPlacementIDs == [placementID])
}

@Test func floorVariantSumsSelectedPlansAndUndoKeepsGeometry() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = WorkspaceStorage(url: directory.appendingPathComponent("workspace.json"))
    let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
    let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
    let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000022")!
    let variantID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let source = Data("scan-bytes".utf8)
    let first = Workspace.Floor.State(id: firstID, name: "Salon", room: try rectangle(widthMm: 4000, heightMm: 3000))
    let second = Workspace.Floor.State(id: secondID, name: "Kuchnia", room: try rectangle(widthMm: 2000, heightMm: 2000))
    let scan = Workspace.Scan.State(id: UUID(uuidString: "00000000-0000-0000-0000-000000000023")!, label: "Skan", rooms: [], sourceUsdz: source)
    var state = Workspace.State(
        projects: [.init(id: projectID, name: "Dom", scans: [scan], floors: [first, second], selectedFloorIDs: [firstID, secondID])],
        selectedProjectID: projectID
    )
    state.hasLoaded = true
    let store = await TestStoreActor(initialState: state) {
        Workspace().environment(\.workspaceFiles, WorkspaceFiles(load: { try storage.load() }, save: { try storage.save($0) }))
    }
    let firstPlan = try first.makePlan()
    let secondPlan = try second.makePlan()

    await store.send(.planSelectedFloorsButtonTapped(projectID)) {
        $0.projects[0].floors[0].plan = firstPlan
        $0.projects[0].floors[1].plan = secondPlan
        $0.projects[0].floorVariants = [FloorVariant(
            id: variantID, floorIDs: [firstID, secondID],
            areaNetMm2: firstPlan.bom.areaNetMm2 + secondPlan.bom.areaNetMm2,
            areaBoughtMm2: firstPlan.bom.areaBoughtMm2 + secondPlan.bom.areaBoughtMm2,
            fullBoards: firstPlan.bom.fullBoards + secondPlan.bom.fullBoards,
            pieces: firstPlan.bom.pieces + secondPlan.bom.pieces,
            packs: (firstPlan.bom.packs ?? 0) + (secondPlan.bom.packs ?? 0)
        )]
    }

    let restored = try storage.load()
    #expect(restored.version == 1)
    #expect(restored.state.projects[0].floorVariants[0].areaNetMm2 == firstPlan.bom.areaNetMm2 + secondPlan.bom.areaNetMm2)
    #expect(restored.state.projects[0].scans[0].sourceUsdz == source)

    await store.send(.projects(projectID, .undoLastFloorVariantButtonTapped)) {
        $0.projects[0].undoneFloorVariantIDs = [variantID]
    }
    let afterUndo = try storage.load().state.projects[0]
    #expect(afterUndo.floors.map(\.room) == [first.room, second.room])
    #expect(afterUndo.scans[0].sourceUsdz == source)
    #expect(afterUndo.floorVariants.count == 1)
    #expect(afterUndo.undoneFloorVariantIDs == [variantID])

    let legacy = Data("""
    {"version":1,"projects":[{"id":"00000000-0000-0000-0000-000000000020","name":"Dom","scans":[],"floors":[],"selectedFloorIDs":[],"splitAtM":"1.500","splitAxis":"x"}]}
    """.utf8)
    let decoded = try JSONDecoder().decode(WorkspaceArchive.self, from: legacy)
    #expect(decoded.state.projects[0].floorVariants.isEmpty)
    #expect(decoded.state.projects[0].undoneFloorVariantIDs.isEmpty)
}

@Test func roomPlanSourceDisclosesUnverifiedGeometricAccuracy() {
    let source = RoomPlanStructureSource(rooms: [Data("room".utf8)], structure: Data("structure".utf8))

    #expect(source.accuracyDisclosure.contains("RoomPlan"))
    #expect(source.accuracyDisclosure.contains("nie została zweryfikowana"))
    #expect(source.accuracyDisclosure.contains("pomiarów referencyjnych"))
}

@Test func completedCameraScanIsSavedWithoutConsumingFreeRoom() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = WorkspaceStorage(url: directory.appendingPathComponent("workspace.json"))
    var state = Workspace.State()
    state.hasLoaded = true
    let store = await TestStoreActor(initialState: state) {
        Workspace().environment(\.workspaceFiles, WorkspaceFiles(load: { try storage.load() }, save: { try storage.save($0) }))
    }
    let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let scanID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    // Opaque adapter output: this tests storage, not Apple's geometry schema.
    let source = Data("{\"walls\":[],\"identifier\":\"test-source\"}".utf8)
    await store.send(.scanRoomButtonTapped) { $0.isCapturingRoom = true }
    await store.send(.roomCaptureFinished(source)) {
        $0.isCapturingRoom = false
        $0.projects = [snap(Workspace.Project.State(id: projectID, name: "Projekt 1", scans: [
            .init(id: scanID, label: "Skan 1", rooms: [], roomPlanJSON: source)
        ]))]
        $0.selectedProjectID = projectID
    }
    let restored = try storage.load().state
    expectNoDifference(restored.projects[0].scans[0].roomPlanJSON, source)
    #expect(restored.freeRoomID == nil)
    #expect(restored.projects[0].floors.isEmpty)
}

@Test func importedUsdzAndCameraScansPreserveTheirOwnSourceKinds() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = WorkspaceStorage(url: directory.appendingPathComponent("workspace.json"))
    let importedSource = twoFloorUsdz()
    let cameraSource = RoomPlanStructureSource(
        rooms: [Data("camera-room-source".utf8)],
        structure: Data("camera-structure-source".utf8)
    )
    let scans = [
        Workspace.Scan.State(id: UUID(), label: "USDZ", rooms: [], sourceUsdz: importedSource),
        Workspace.Scan.State(id: UUID(), label: "RoomPlan", rooms: [], roomPlanStructure: cameraSource),
    ]
    let project = Workspace.Project.State(id: UUID(), name: "Dom", scans: scans)
    try storage.save(WorkspaceArchive(Workspace.State(projects: [project])))

    let restored = try storage.load().state.projects[0].scans
    #expect(restored.count == 2)
    #expect(restored[0].sourceUsdz == importedSource)
    #expect(restored[0].roomPlanStructure == nil)
    #expect(restored[1].sourceUsdz == nil)
    #expect(restored[1].roomPlanStructure == cameraSource)
}

@Test func completedStructurePreservesAllSourcesAcrossReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = WorkspaceStorage(url: directory.appendingPathComponent("workspace.json"))
    let projectID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    let scanID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    var state = Workspace.State(projects: [.init(id: projectID, name: "Dom")], selectedProjectID: projectID)
    state.hasLoaded = true
    let store = await TestStoreActor(initialState: state) {
        Workspace().environment(\.workspaceFiles, WorkspaceFiles(load: { try storage.load() }, save: { try storage.save($0) }))
    }
    // Opaque adapter bytes, not a fabricated Apple geometry fixture.
    let source = RoomPlanStructureSource(rooms: [Data("kitchen".utf8), Data("hall".utf8)], structure: Data("assembled".utf8))
    await store.send(.scanRoomButtonTapped) { $0.isCapturingRoom = true }
    await store.send(.structureCaptureFinished(source)) {
        $0.isCapturingRoom = false
        $0.projects[0].scans = [snap(Workspace.Scan.State(id: scanID, label: "Skan 1", rooms: [], roomPlanStructure: source))]
    }
    let restored = try storage.load().state
    expectNoDifference(restored.projects[0].scans[0].roomPlanStructure, source)
    #expect(restored.freeRoomID == nil)
    #expect(!restored.hasPro)
    #expect(restored.projects[0].floors.isEmpty)
    #expect(restored.projects[0].scans[0].roomPlanJSON == nil)
}

@Test func captureCancelIgnoresLateResult() async {
    let store = await TestStoreActor(initialState: Workspace.State()) { Workspace() }
    await store.send(.scanRoomButtonTapped) { $0.isCapturingRoom = true }
    await store.send(.roomCaptureCancelled) { $0.isCapturingRoom = false }
    await store.send(.roomCaptureFinished(Data("late".utf8)))
    await store.send(.roomCaptureFailed("late failure"))
    await store.send(.structureCaptureFinished(.init(rooms: [Data("late".utf8)], structure: Data("late".utf8))))
}

@Test func captureFailureLeavesProjectUntouched() async {
    let store = await TestStoreActor(initialState: Workspace.State()) { Workspace() }
    await store.send(.scanRoomButtonTapped) { $0.isCapturingRoom = true }
    await store.send(.roomCaptureFailed("Brak dostępu do aparatu.")) {
        $0.isCapturingRoom = false
        $0.error = "Brak dostępu do aparatu."
    }
}

@Test func damagedArchiveBlocksCameraCapture() async {
    var state = Workspace.State()
    state.storageError = Workspace.loadFailureMessage
    let store = await TestStoreActor(initialState: state) { Workspace() }
    await store.send(.scanRoomButtonTapped)
    await store.send(.roomCaptureFinished(Data("late".utf8)))
    await store.send(.structureCaptureFinished(.init(rooms: [Data("late".utf8)], structure: Data("late".utf8))))
}

@Test func emptyStructureDoesNotCreateProject() async {
    for source in [
        RoomPlanStructureSource(rooms: [], structure: Data("structure".utf8)),
        RoomPlanStructureSource(rooms: [Data()], structure: Data("structure".utf8)),
        RoomPlanStructureSource(rooms: [Data("room".utf8)], structure: Data())
    ] {
        let store = await TestStoreActor(initialState: Workspace.State()) { Workspace() }
        await store.send(.scanRoomButtonTapped) { $0.isCapturingRoom = true }
        await store.send(.structureCaptureFinished(source)) {
            $0.isCapturingRoom = false
            $0.error = "Skan jest pusty. Spróbuj ponownie."
        }
    }
}

@Test func emptyCaptureDoesNotCreateProject() async {
    let store = await TestStoreActor(initialState: Workspace.State()) { Workspace() }
    await store.send(.scanRoomButtonTapped) { $0.isCapturingRoom = true }
    await store.send(.roomCaptureFinished(Data())) {
        $0.isCapturingRoom = false
        $0.error = "Skan jest pusty. Spróbuj ponownie."
    }
}

@Test func versionOneArchiveWithoutCorrectionsLoadsUnchanged() throws {
    let legacyArchive = Data(#"""
    {
      "version": 1,
      "projects": [{
        "id": "00000000-0000-0000-0000-000000000001",
        "name": "Dom",
        "scans": [],
        "floors": [],
        "selectedFloorIDs": [],
        "splitAtM": "1.500",
        "splitAxis": "x"
      }]
    }
    """#.utf8)

    let decoded = try JSONDecoder().decode(WorkspaceArchive.self, from: legacyArchive)

    #expect(decoded.version == 1)
    #expect(decoded.state.projects[0].geometryCorrections.isEmpty)
}

@Test func versionOneArchiveWithoutImportedSourceLoadsUnchanged() throws {
    // Fixed version-one shape from before imported USDZ payloads were retained in ScanRecord.
    let legacyArchive = Data(#"""
    {
      "version": 1,
      "projects": [{
        "id": "00000000-0000-0000-0000-000000000001",
        "name": "Dom",
        "scans": [{
          "id": "00000000-0000-0000-0000-000000000002",
          "label": "Stary skan",
          "rooms": []
        }],
        "floors": [],
        "selectedFloorIDs": [],
        "splitAtM": "1.500",
        "splitAxis": "x"
      }]
    }
    """#.utf8)

    let decoded = try JSONDecoder().decode(WorkspaceArchive.self, from: legacyArchive)

    #expect(decoded.version == 1)
    #expect(decoded.state.projects.count == 1)
    #expect(decoded.state.projects[0].name == "Dom")
    #expect(decoded.state.projects[0].scans[0].label == "Stary skan")
    #expect(decoded.state.projects[0].scans[0].sourceUsdz == nil)
}

@Test func listedSourceOmitsScansWithoutStructureOrUsdz() {
    #expect(RoomPlanStructureSource.listedSourceTitle(label: "Parter", roomCount: 2, hasSourceUsdz: false)
        == "Parter · 2 pokoi z jednej sesji RoomPlan")
    #expect(RoomPlanStructureSource.listedSourceTitle(label: "Import", roomCount: nil, hasSourceUsdz: true)
        == "Import · oryginalny USDZ zachowany")
    #expect(RoomPlanStructureSource.listedSourceTitle(label: "Pusty", roomCount: nil, hasSourceUsdz: false) == nil)
}

@Test func houseScenePersistsUtilitiesWallsFurnitureAndDrill() throws {
    let wall = WallSegment(id: UUID(), start: ScenePoint(xMm: 0, yMm: 0, zMm: 0), end: ScenePoint(xMm: 4000, yMm: 0, zMm: 0), heightMm: 2600, finish: "biala")
    let routeID = UUID()
    let route = UtilityRoute(id: routeID, name: "Woda", colorName: "niebieski", diameterMm: 20, points: [ScenePoint(xMm: 100, yMm: 0, zMm: 1000), ScenePoint(xMm: 100, yMm: 0, zMm: 1400)], state: .existing, source: .measurement, confidence: .unverified)
    let sofa = FurnitureItem(id: UUID(), name: "Kanapa", size: ScenePoint(xMm: 2000, yMm: 900, zMm: 800), origin: ScenePoint(xMm: 0, yMm: 0, zMm: 0), state: .planned)
    var project = Workspace.Project.State(id: UUID(), name: "Dom")
    project.walls = [wall]
    project.utilities = [route]
    project.furniture = [sofa]
    let bytes = Data("usdz".utf8)
    project.scans = [.init(id: UUID(), label: "A", rooms: [], sourceUsdz: bytes, transform: ScanTransform(xMm: 10, yMm: 0, zMm: 0, yawDegrees: 0))]
    let archive = WorkspaceArchive(Workspace.State(projects: [project]))
    let restored = try JSONDecoder().decode(WorkspaceArchive.self, from: JSONEncoder().encode(archive)).state.projects[0]
    #expect(restored.walls == [wall])
    #expect(restored.utilities[0].confidence == .unverified)
    #expect(restored.furniture == [sofa])
    #expect(restored.scans[0].sourceUsdz == bytes)

    let query = DrillQuery(origin: ScenePoint(xMm: 100, yMm: 0, zMm: 900), direction: ScenePoint(xMm: 0, yMm: 0, zMm: 1), depthMm: 600)
    guard case .hits(let hits) = HouseScene.drill(query, routes: restored.utilities) else {
        Issue.record("Brak trafienia")
        return
    }
    #expect(hits.map(\.routeID) == [routeID])
    #expect(hits[0].confidence == .unverified)
    let miss = DrillQuery(origin: ScenePoint(xMm: 5000, yMm: 0, zMm: 0), direction: ScenePoint(xMm: 0, yMm: 0, zMm: 1), depthMm: 100)
    #expect(HouseScene.drill(miss, routes: restored.utilities) == .hits([]))
    #expect(HouseScene.drill(query, routes: []) == .unknown)

    let scene = HouseScene.scene(walls: restored.walls, routes: restored.utilities, furniture: restored.furniture)
    #expect(scene.rootNode.childNodes.contains { $0.name?.hasPrefix("wall.") == true })
    #expect(scene.rootNode.childNodes.contains { $0.name?.contains("unverified") == true })
    #expect(scene.rootNode.childNodes.contains { $0.name?.hasPrefix("furniture.") == true })

    let legacy = Data("""
    {"version":1,"projects":[{"id":"00000000-0000-0000-0000-000000000020","name":"Dom","scans":[],"floors":[],"selectedFloorIDs":[],"splitAtM":"1.500","splitAxis":"x"}]}
    """.utf8)
    let decoded = try JSONDecoder().decode(WorkspaceArchive.self, from: legacy).state.projects[0]
    #expect(decoded.walls.isEmpty && decoded.utilities.isEmpty && decoded.furniture.isEmpty)

    let box = MDLMesh.newBox(withDimensions: SIMD3<Float>(1, 1, 1), segments: SIMD3<UInt32>(1, 1, 1), geometryType: .triangles, inwardNormals: false, allocator: nil)
    let asset = MDLAsset()
    asset.add(box)
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".usd")
    try asset.export(to: file)
    let meshBytes = try Data(contentsOf: file)
    let transform = ScanTransform(xMm: 250, yMm: 0, zMm: 0, yawDegrees: 90)
    let node = try #require(HouseScene.mesh(bytes: meshBytes, transform: transform))
    #expect(node.name == "scan.mesh")
    #expect(node.position.x == 0.25)
    #expect(node.childNodes.isEmpty == false || node.geometry != nil)
    #expect(HouseScene.mesh(bytes: Data("not a mesh".utf8), transform: .identity) == nil)
    #expect(try Data(contentsOf: file) == meshBytes)
}
