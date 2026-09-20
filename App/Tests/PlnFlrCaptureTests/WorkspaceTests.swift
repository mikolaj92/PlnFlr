import ComposableArchitecture2
import Foundation
import PlnFlrCapture
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
    let store = await TestStoreActor(initialState: Workspace.State()) {
        Workspace()
    }
    await store.send(.importUsdz(twoFloorUsdz())) {
        $0.projects = [
            snap(
                Workspace.Project.State(
                    id: projectID,
                    name: "Projekt 1",
                    scans: [
                        Workspace.Scan.State(
                            id: scanID,
                            label: "Skan 1",
                            rooms: captured.rooms
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
    await store.send(.splitSelectedButtonTapped) {
        $0.projects[0].floors = [
            snap(Workspace.Floor.State(id: leftID, name: "Salon A", room: left!)),
            snap(Workspace.Floor.State(id: rightID, name: "Salon B", room: right!)),
        ]
        $0.projects[0].selectedFloorIDs = [leftID]
    }
}

@Test func joinSelectedMergesWorkingFloors() async throws {
    let left = try rectangle(widthMm: 1500, heightMm: 3000)
    let right = try Room(
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
    let store = await TestStoreActor(
        initialState: Workspace.State(
            projects: [
                Workspace.Project.State(
                    id: projectID,
                    name: "Projekt 1",
                    floors: [
                        Workspace.Floor.State(id: leftID, name: "Salon A", room: left),
                        Workspace.Floor.State(id: rightID, name: "Salon B", room: right),
                    ],
                    selectedFloorIDs: [leftID, rightID]
                ),
            ],
            selectedProjectID: projectID
        )
    ) {
        Workspace()
    }
    let joined = try joinRooms(left, right)
    await store.send(.joinSelectedButtonTapped) {
        $0.projects[0].floors = [
            snap(Workspace.Floor.State(id: joinedID, name: "Salon A", room: joined)),
        ]
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
    let store = await TestStoreActor(
        initialState: Workspace.Floor.State(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Salon",
            room: room
        )
    ) {
        Workspace.Floor()
    }
    await store.send(.layButtonTapped) {
        $0.plan = expected
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
