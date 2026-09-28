import ComposableArchitecture2
import Foundation
@testable import PlnFlrCapture
import PlnFlrLayout
import Testing

@Test func newProjectCreatesEmptyProject() async {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let store = await TestStoreActor(initialState: Workspace.State()) {
        Workspace()
    }
    await store.send(.newProjectButtonTapped) {
        $0.projects = [
            snap(Workspace.Project.State(id: id, name: "Projekt 1")),
        ]
        $0.selectedProjectID = id
    }
}

@Test func importUsdzAddsScanAndWorkingFloors() async throws {
    let captured = try roomFromUsdz(twoFloorUsdz())
    let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let scanID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let salonID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    let bedID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    let sourceUsdz = twoFloorUsdz()
    let store = await TestStoreActor(initialState: Workspace.State()) {
        Workspace()
    }
    await store.send(.importUsdz(sourceUsdz)) {
        $0.projects = [
            snap(
                Workspace.Project.State(
                    id: projectID,
                    name: "Projekt 1",
                    scans: [
                        Workspace.Scan.State(
                            id: scanID,
                            label: "Skan 1",
                            rooms: captured.rooms,
                            sourceUsdz: sourceUsdz
                        ),
                    ],
                    floors: [
                        Workspace.Floor.State(
                            id: salonID,
                            name: "Salon",
                            room: captured.rooms[0].room,
                            thresholds: captured.rooms[0].thresholds,
                            windows: captured.rooms[0].windows
                        ),
                        Workspace.Floor.State(
                            id: bedID,
                            name: "Sypialnia",
                            room: captured.rooms[1].room,
                            thresholds: captured.rooms[1].thresholds,
                            windows: captured.rooms[1].windows
                        ),
                    ],
                    selectedFloorIDs: [salonID]
                )
            ),
        ]
        $0.selectedProjectID = projectID
    }
    #expect(await store.projects[0].scans[0].sourceUsdz == sourceUsdz)
}

@Test func splitPersistsOriginalGeometryAndCorrectionLineage() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = WorkspaceStorage(url: directory.appendingPathComponent("workspace.json"))
    let room = try rectangle(widthMm: 4000, heightMm: 3000)
    let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
    let originalID = UUID(uuidString: "00000000-0000-0000-0000-000000000098")!
    let leftID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let rightID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let source = Data("original-usdz".utf8)
    let scan = Workspace.Scan.State(id: UUID(uuidString: "00000000-0000-0000-0000-000000000097")!, label: "Skan", rooms: [], sourceUsdz: source)
    var state = Workspace.State(
        projects: [.init(id: projectID, name: "Dom", scans: [scan], floors: [.init(id: originalID, name: "Salon", room: room)], selectedFloorIDs: [originalID])],
        selectedProjectID: projectID
    )
    state.hasLoaded = true
    let store = await TestStoreActor(initialState: state) {
        Workspace().environment(\.workspaceFiles, WorkspaceFiles(load: { try storage.load() }, save: { try storage.save($0) }))
    }
    let (left, right) = try splitRoom(room, axis: .x, atMm: 1500)
    let first = Workspace.Floor.State(id: leftID, name: "Salon A", room: left!, accessID: originalID)
    let second = Workspace.Floor.State(id: rightID, name: "Salon B", room: right!, accessID: originalID)
    let expectedCorrection = GeometryCorrection(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        operation: .split(axis: .x, atMm: 1500),
        before: [FloorSnapshot(Workspace.Floor.State(id: originalID, name: "Salon", room: room))],
        after: [FloorSnapshot(first), FloorSnapshot(second)]
    )

    await store.send(.splitSelectedButtonTapped) {
        $0.projects[0].floors = [
            snap(first),
            snap(second),
        ]
        $0.projects[0].geometryCorrections = [expectedCorrection]
        $0.projects[0].selectedFloorIDs = [leftID]
    }

    let restored = try storage.load().state
    let corrections = restored.projects[0].geometryCorrections
    #expect(corrections.count == 1)
    let correction = corrections[0]
    #expect(correction.operation == GeometryCorrection.Operation.split(axis: .x, atMm: 1500))
    #expect(correction.before.map { $0.id } == [originalID])
    #expect(correction.before[0].name == "Salon")
    #expect(correction.before[0].room == room)
    #expect(correction.after.map { $0.id } == [leftID, rightID])
    #expect(restored.projects[0].floors.map { $0.id } == correction.after.map { $0.id })
    #expect(correction.before[0].room.outer.vertices.map { $0.xMm }.max() == 4000)
    let archivedAgain = WorkspaceArchive(restored)
    #expect(archivedAgain.state.projects[0].geometryCorrections == [correction])
    #expect(correction.before[0].state.room == room)
    var undoInitialState = restored
    undoInitialState.hasLoaded = true
    let undo = await TestStoreActor(initialState: undoInitialState) {
        Workspace().environment(\.workspaceFiles, WorkspaceFiles(load: { try storage.load() }, save: { try storage.save($0) }))
    }
    await undo.send(.projects(projectID, .undoLastGeometryCorrectionButtonTapped)) {
        $0.projects[0].floors = [snap(correction.before[0].state)]
        $0.projects[0].undoneGeometryCorrectionIDs = [correction.id]
        $0.projects[0].selectedFloorIDs = [originalID]
    }
    let restoredAfterUndo = try storage.load().state
    #expect(restoredAfterUndo.projects[0].geometryCorrections == [correction])
    #expect(restoredAfterUndo.projects[0].undoneGeometryCorrectionIDs == [correction.id])
    #expect(restoredAfterUndo.projects[0].floors.map { $0.room } == [room])
    #expect(restoredAfterUndo.projects[0].scans[0].sourceUsdz == source)
}

@Test func splitSelectedCutsWorkingFloor() async throws {
    let room = try rectangle(widthMm: 4000, heightMm: 3000)
    let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
    let originalID = UUID(uuidString: "00000000-0000-0000-0000-000000000098")!
    let leftID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let rightID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let store = await TestStoreActor(
        initialState: Workspace.State(
            projects: [
                Workspace.Project.State(
                    id: projectID,
                    name: "Projekt 1",
                    floors: [
                        Workspace.Floor.State(id: originalID, name: "Salon", room: room),
                    ],
                    selectedFloorIDs: [originalID],
                    splitAtM: "1.500"
                ),
            ],
            selectedProjectID: projectID
        )
    ) {
        Workspace()
    }
    let (left, right) = try splitRoom(room, axis: .x, atMm: 1500)
    let original = Workspace.Floor.State(id: originalID, name: "Salon", room: room)
    let first = Workspace.Floor.State(id: leftID, name: "Salon A", room: left!, accessID: originalID)
    let second = Workspace.Floor.State(id: rightID, name: "Salon B", room: right!, accessID: originalID)
    let correction = GeometryCorrection(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, operation: .split(axis: .x, atMm: 1500), before: [FloorSnapshot(original)], after: [FloorSnapshot(first), FloorSnapshot(second)])
    await store.send(.splitSelectedButtonTapped) {
        $0.projects[0].floors = [snap(first), snap(second)]
        $0.projects[0].geometryCorrections = [correction]
        $0.projects[0].selectedFloorIDs = [leftID]
    }
}

@Test func joinPersistsBothOriginalGeometriesInCorrectionLineage() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = WorkspaceStorage(url: directory.appendingPathComponent("workspace.json"))
    let left = try rectangle(widthMm: 1500, heightMm: 3000)
    let right = Room(try Ring([
        Vertex(1500, 0), Vertex(4000, 0), Vertex(4000, 3000), Vertex(1500, 3000),
    ]))
    let leftID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    let rightID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
    let joinedID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let joinedRoom = try joinRooms(left, right)
    var expectedJoined = Workspace.Floor.State(id: joinedID, name: "Salon A", room: joinedRoom, accessID: joinedID)
    expectedJoined.copyMaterial(from: Workspace.Floor.State(id: leftID, name: "Salon A", room: left, accessID: leftID))
    let expectedCorrection = GeometryCorrection(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        operation: .join,
        before: [
            FloorSnapshot(Workspace.Floor.State(id: leftID, name: "Salon A", room: left, accessID: leftID)),
            FloorSnapshot(Workspace.Floor.State(id: rightID, name: "Salon B", room: right, accessID: rightID)),
        ],
        after: [FloorSnapshot(expectedJoined)]
    )
    var state = Workspace.State(
        projects: [.init(id: projectID, name: "Dom", floors: [
            .init(id: leftID, name: "Salon A", room: left, accessID: leftID),
            .init(id: rightID, name: "Salon B", room: right, accessID: rightID),
        ], selectedFloorIDs: [leftID, rightID])],
        selectedProjectID: projectID
    )
    state.hasLoaded = true
    let store = await TestStoreActor(initialState: state) {
        Workspace().environment(\.workspaceFiles, WorkspaceFiles(load: { try storage.load() }, save: { try storage.save($0) }))
    }

    await store.send(.joinSelectedButtonTapped) {
        var joinedFloor = Workspace.Floor.State(id: joinedID, name: "Salon A", room: joinedRoom, accessID: joinedID)
        let originalFloor = Workspace.Floor.State(id: leftID, name: "Salon A", room: left, accessID: leftID)
        joinedFloor.copyMaterial(from: originalFloor)
        $0.projects[0].floors = [snap(joinedFloor)]
        $0.projects[0].geometryCorrections = [expectedCorrection]
        $0.projects[0].selectedFloorIDs = [joinedID]
    }

    let correction = try #require(try storage.load().state.projects[0].geometryCorrections.first)
    #expect(correction.operation == GeometryCorrection.Operation.join)
    #expect(correction.before.map { $0.room } == [left, right])
    #expect(correction.after.map { $0.room } == [joinedRoom])
    #expect(try storage.load().state.projects[0].floors.map { $0.room } == correction.after.map { $0.room })
}

@Test func joinSelectedMergesWorkingFloors() async throws {
    let left = try rectangle(widthMm: 1500, heightMm: 3000)
    let right = Room(
        try Ring([
            Vertex(1500, 0),
            Vertex(4000, 0),
            Vertex(4000, 3000),
            Vertex(1500, 3000),
        ])
    )
    let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
    let leftID = UUID(uuidString: "00000000-0000-0000-0000-000000000098")!
    let rightID = UUID(uuidString: "00000000-0000-0000-0000-000000000097")!
    let joinedID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let project = Workspace.Project.State(id: projectID, name: "Projekt 1", floors: [
        Workspace.Floor.State(id: leftID, name: "Salon A", room: left),
        Workspace.Floor.State(id: rightID, name: "Salon B", room: right),
    ], selectedFloorIDs: [leftID, rightID])
    let store = await TestStoreActor(initialState: Workspace.State(projects: [project], selectedProjectID: projectID)) {
        Workspace()
    }
    let joined = try joinRooms(left, right)
    var joinedFloor = Workspace.Floor.State(id: joinedID, name: "Salon A", room: joined)
    joinedFloor.copyMaterial(from: project.floors[0])
    let correction = GeometryCorrection(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, operation: .join, before: project.floors.map(FloorSnapshot.init), after: [FloorSnapshot(joinedFloor)])
    await store.send(.joinSelectedButtonTapped) {
        $0.projects[0].floors = [snap(joinedFloor)]
        $0.projects[0].geometryCorrections = [correction]
        $0.projects[0].selectedFloorIDs = [joinedID]
    }
}

@Test func layButtonTappedUsesFloorGeometry() async throws {
    let room = try rectangle(widthMm: 4000, heightMm: 3000)
    let spec = PlankSpec(lengthMm: 1383, widthMm: 156, boardsPerPack: 8)
    let expected = try layoutFloor(
        room,
        zones: [Zone(kind: .plank, plank: spec)],
        rules: LayoutRules(expansionMm: 10)
    )
    let floor = Workspace.Floor.State(id: UUID(), name: "Salon", room: room)
    let project = Workspace.Project.State(id: UUID(), name: "Dom", floors: [floor])
    let store = await TestStoreActor(initialState: Workspace.State(projects: [project])) { Workspace() }
    await store.send(.planFloorButtonTapped(project.id, floor.id)) {
        $0.projects[0].floors[0].plan = expected
        $0.freeRoomID = floor.id
    }
}

func twoFloorUsdz() -> Data {
    let root = """
    #usda 1.0
    (
        defaultPrim = "Scan"
        metersPerUnit = 1
        upAxis = "Y"
    )

    def Xform "Scan" (
        kind = "assembly"
    )
    {
        def Xform "Section_grp" ( kind = "group" )
        {
            def Xform "livingRoom0" ( kind = "assembly" ) { }
            def Xform "bedRoom0" ( kind = "assembly" ) { }
        }
        def Xform "Mesh_grp" ( kind = "group" )
        {
            def Xform "Floor_grp" (
                kind = "group"
                prepend references = @./assets/Mesh/Floors/Floor0.usda@
            ) { }
            def Xform "Floor_grp_1" (
                kind = "group"
                prepend references = @./assets/Mesh/Floors/Floor1.usda@
            ) { }
            def Xform "Arch_grp" ( kind = "group" )
            {
                def Xform "Wall_0_grp" (
                    kind = "group"
                    prepend references = @./assets/Mesh/Walls/Wall0/Door0.usda@
                ) { }
            }
        }
    }
    """
    let salon = usdaMesh(
        name: "Floor0",
        category: "Floor",
        points: "(0, 0, 0), (4, 0, 0), (4, 3, 0), (0, 3, 0), (0, 0, -0.16), (4, 0, -0.16), (4, 3, -0.16), (0, 3, -0.16)",
        counts: "3, 3, 3, 3",
        indices: "0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6",
        matrix: "( (1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1) )"
    )
    let bed = usdaMesh(
        name: "Floor1",
        category: "Floor",
        points: "(5, 0, 0), (8, 0, 0), (8, 3, 0), (5, 3, 0), (5, 0, -0.16), (8, 0, -0.16), (8, 3, -0.16), (5, 3, -0.16)",
        counts: "3, 3, 3, 3",
        indices: "0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6",
        matrix: "( (1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1) )"
    )
    return zipData([
        "Scan.usda": Data(root.utf8),
        "assets/Mesh/Floors/Floor0.usda": Data(salon.utf8),
        "assets/Mesh/Floors/Floor1.usda": Data(bed.utf8),
        "assets/Mesh/Walls/Wall0/Door0.usda": Data(boxUsda(name: "Door0", category: "Door(Isopen: False)", hx: 0.45, hy: 1.0, hz: 0.04, tx: 2.0, ty: 1.0, tz: 0.04).utf8),
    ])
}

private func usdaMesh(name: String, category: String, points: String, counts: String, indices: String, matrix: String) -> String {
    """
    #usda 1.0
    (
        defaultPrim = "\(name)"
        metersPerUnit = 1
        upAxis = "Y"
    )

    def Xform "\(name)" (
        customData = {
            string Category = "\(category)"
            string UUID = "00000000-0000-0000-0000-000000000000"
        }
        kind = "component"
    )
    {
        def Mesh "\(name)"
        {
            int[] faceVertexCounts = [\(counts)]
            int[] faceVertexIndices = [\(indices)]
            point3f[] points = [\(points)]
            matrix4d xformOp:transform = \(matrix)
            uniform token[] xformOpOrder = ["xformOp:transform"]
        }
    }
    """
}

private func boxUsda(name: String, category: String, hx: Double, hy: Double, hz: Double, tx: Double, ty: Double, tz: Double) -> String {
    let points = "(\(-hx), \(-hy), \(-hz)), (\(hx), \(-hy), \(-hz)), (\(hx), \(hy), \(-hz)), (\(-hx), \(hy), \(-hz)), (\(-hx), \(-hy), \(hz)), (\(hx), \(-hy), \(hz)), (\(hx), \(hy), \(hz)), (\(-hx), \(hy), \(hz))"
    return usdaMesh(
        name: name,
        category: category,
        points: points,
        counts: "3, 3",
        indices: "0, 1, 2, 0, 2, 3",
        matrix: "( (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), (\(tx), \(ty), \(tz), 1) )"
    )
}

private func zipData(_ files: [String: Data]) -> Data {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for (name, data) in files {
        let url = dir.appendingPathComponent(name)
        try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! data.write(to: url)
    }
    let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    task.currentDirectoryURL = dir
    task.arguments = ["-r", "-q", zipURL.path, "."]
    try! task.run()
    task.waitUntilExit()
    return try! Data(contentsOf: zipURL)
}
