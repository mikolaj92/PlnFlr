import Foundation
import PlnFlrLayout
import Testing

@Test func roomplanFloorIsPolygonInMillimetres() throws {
    let captured = try roomFromUsdz(salonUsdz())
    #expect(captured.rooms.count == 1)
    let salon = captured.rooms[0]
    #expect(salon.name == "Salon")
    let verts = salon.room.outer.vertices.map { ($0.xMm, $0.yMm) }
    #expect(verts.contains { $0 == (0, 0) })
    #expect(verts.contains { $0 == (4000, 0) })
    #expect(verts.contains { $0 == (4000, 3000) })
    #expect(verts.contains { $0 == (0, 3000) })
    #expect(verts.count == 4)
    #expect(salon.room.outer.vertices[0] == Vertex(0, 0))
}

@Test func roomplanFireplaceIsAHole() throws {
    let salon = try roomFromUsdz(salonUsdz()).rooms[0]
    #expect(salon.room.holes.count == 2)
    let fire = salon.room.holes[0]
    let xs = fire.vertices.map(\.xMm)
    let ys = fire.vertices.map(\.yMm)
    #expect(xs.min() == 700 && xs.max() == 1300)
    #expect(ys.min() == 1100 && ys.max() == 1900)
}

@Test func roomplanDoorIsThresholdStrip() throws {
    let salon = try roomFromUsdz(salonUsdz()).rooms[0]
    #expect(salon.thresholds.count == 1)
    let strip = salon.thresholds[0]
    #expect(strip.label == "listwa progowa")
    #expect(strip.lengthMm == 900)
    #expect(strip.widthMm == 80)
    let door = salon.room.holes[1]
    let xs = door.vertices.map(\.xMm)
    let ys = door.vertices.map(\.yMm)
    #expect(xs.min() == 1550 && xs.max() == 2450)
    #expect(ys.min() == 0 && ys.max() == 80)
}

@Test func roomplanWindowIsOpeningNotHole() throws {
    let salon = try roomFromUsdz(salonUsdz()).rooms[0]
    #expect(salon.windows.count == 1)
    let window = salon.windows[0]
    #expect(window.label == "okno")
    let xs = [window.start.xMm, window.end.xMm]
    let ys = [window.start.yMm, window.end.yMm]
    #expect(xs.min() == 1500 && xs.max() == 2500)
    #expect(ys.min() == 0 && ys.max() == 0)
}

@Test func usdzWithTwoFloorsYieldsTwoRooms() throws {
    let captured = try roomFromUsdz(twoFloorUsdz())
    #expect(captured.rooms.count == 2)
    #expect(captured.rooms[0].name == "Salon")
    #expect(captured.rooms[1].name == "Sypialnia")
    let salon = captured.rooms[0].room.outer.vertices.map { ($0.xMm, $0.yMm) }
    #expect(salon.contains { $0 == (0, 0) })
    #expect(salon.contains { $0 == (4000, 3000) })
    let bed = captured.rooms[1].room.outer.vertices.map { ($0.xMm, $0.yMm) }
    #expect(bed.contains { $0 == (5000, 0) })
    #expect(bed.contains { $0 == (8000, 3000) })
    #expect(captured.rooms[0].thresholds.count == 1)
    #expect(captured.rooms[1].thresholds.isEmpty)
}

func salonUsdz() -> Data {
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
