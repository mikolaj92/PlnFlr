import Foundation
import HTTPTypes
import PlnFlrWeb
import Testing
import Vapor
import VaporTesting

func withWeb(
    scanMaxBytes: Int = 8 * 1024 * 1024,
    _ body: (any TestClient, RoomStore) async throws -> Void
) async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let store = RoomStore(path: dir.appendingPathComponent("rooms.json"))
    try await withApp(configure: { app in
        try await configure(app, rooms: store, scanMaxBytes: scanMaxBytes)
    }) { app in
        try await app.testing { client in
            try await body(client, store)
        }
    }
}

func html(_ res: ClientResponse) async throws -> String {
    try await res.body.string(max: .unlimited) ?? ""
}

extension HTTPFields {
    var hxRedirect: String? { self[HTTPField.Name("HX-Redirect")!] }
}

struct LayoutPost: Content {
    static let defaultContentType: HTTPMediaType = .urlEncodedForm
    var shape: String = "rect"
    var kind: String = "plank"
    var kind_b: String = "tile"
    var width_m: String = "4.000"
    var height_m: String = "3.000"
    var l_span_x_m: String = "6.000"
    var l_span_y_m: String = "4.000"
    var l_cutout_x_m: String = "2.500"
    var l_cutout_y_m: String = "2.000"
    var vertices: String = ""
    var hole_rectangles: String = ""
    var hole_vertices: String = ""
    var door_rectangles: String = ""
    var door_vertices: String = ""
    var window_segments: String = ""
    var plank_length_m: String = "1.383"
    var plank_width_m: String = "0.156"
    var boards_per_pack: String = "8"
    var tile_length_m: String = "0.600"
    var tile_width_m: String = "0.600"
    var grout_mm: String = "3"
    var expansion_mm: String = ""
    var direction: String = "along_long"
    var stagger: String = "third"
    var angle_deg: String = "0"
    var split: String = "none"
    var split_at_m: String = ""
}

struct NewRoomPost: Content {
    static let defaultContentType: HTTPMediaType = .urlEncodedForm
    var name: String
}

struct ScanPost: Content {
    static let defaultContentType: HTTPMediaType = .formData
    var scan: File
}
