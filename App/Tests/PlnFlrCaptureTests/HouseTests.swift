import ComposableArchitecture2
import Foundation
import PlnFlrCapture
import PlnFlrLayout
import Testing

@Test func importUsdzAddsRoomToHouse() async throws {
    let captured = try roomFromUsdz(salonUsdz())
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let store = await TestStoreActor(initialState: House.State()) {
        House()
    }
    await store.send(.importUsdz(salonUsdz())) {
        $0.rooms = [
            House.RoomItem(
                id: id,
                name: "Salon",
                room: captured.room,
                thresholds: captured.thresholds,
                windows: captured.windows
            ),
        ]
        $0.selectedID = id
    }
}

@Test func splitSelectedCutsHouseIntoTwoRooms() async throws {
    let room = try rectangle(widthMm: 4000, heightMm: 3000)
    let originalID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
    let leftID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let rightID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let store = await TestStoreActor(
        initialState: House.State(
            rooms: [
                House.RoomItem(
                    id: originalID,
                    name: "Salon",
                    room: room,
                    thresholds: [],
                    windows: []
                ),
            ],
            selectedID: originalID,
            splitAtM: "1.500"
        )
    ) {
        House()
    }
    let (left, right) = try splitRoom(room, axis: .x, atMm: 1500)
    await store.send(.splitSelectedButtonTapped) {
        $0.rooms = [
            House.RoomItem(
                id: leftID,
                name: "Salon A",
                room: left!,
                thresholds: [],
                windows: []
            ),
            House.RoomItem(
                id: rightID,
                name: "Salon B",
                room: right!,
                thresholds: [],
                windows: []
            ),
        ]
        $0.selectedID = leftID
    }
}

private func salonUsdz() -> Data {
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
        }
        def Xform "Mesh_grp" ( kind = "group" )
        {
            def Xform "Floor_grp" (
                kind = "group"
                prepend references = @./assets/Mesh/Floors/Floor0.usda@
            ) { }
            def Xform "Object_grp" ( kind = "group" )
            {
                def Xform "Fireplace_grp" (
                    kind = "group"
                    prepend references = @./assets/Mesh/Fireplace/Fireplace0.usda@
                ) { }
            }
            def Xform "Arch_grp" ( kind = "group" )
            {
                def Xform "Wall_0_grp" (
                    kind = "group"
                    prepend references = @./assets/Mesh/Walls/Wall0/Door0.usda@
                ) { }
                def Xform "Wall_1_grp" (
                    kind = "group"
                    prepend references = @./assets/Mesh/Walls/Wall1/Window0.usda@
                ) { }
            }
        }
    }
    """
    let floorPoints = "(0, 0, 0), (4, 0, 0), (4, 3, 0), (0, 3, 0), (0, 0, -0.16), (4, 0, -0.16), (4, 3, -0.16), (0, 3, -0.16)"
    let floor = usdaMesh(
        name: "Floor0",
        category: "Floor",
        points: floorPoints,
        counts: "3, 3, 3, 3",
        indices: "0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6",
        matrix: "( (1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1) )"
    )
    return zipData([
        "Scan.usda": Data(root.utf8),
        "assets/Mesh/Floors/Floor0.usda": Data(floor.utf8),
        "assets/Mesh/Fireplace/Fireplace0.usda": Data(boxUsda(name: "Fireplace0", category: "Fireplace", hx: 0.3, hy: 0.5, hz: 0.4, tx: 1.0, ty: 0.5, tz: 1.5).utf8),
        "assets/Mesh/Walls/Wall0/Door0.usda": Data(boxUsda(name: "Door0", category: "Door(Isopen: False)", hx: 0.45, hy: 1.0, hz: 0.04, tx: 2.0, ty: 1.0, tz: 0.04).utf8),
        "assets/Mesh/Walls/Wall1/Window0.usda": Data(boxUsda(name: "Window0", category: "Window", hx: 0.5, hy: 0.6, hz: 0.04, tx: 2.0, ty: 1.0, tz: 0.0).utf8),
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
