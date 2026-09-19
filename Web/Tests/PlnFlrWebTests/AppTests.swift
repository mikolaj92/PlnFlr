import Foundation
import HTTPTypes
import Testing
import Vapor
import VaporTesting
import PlnFlrWeb

@Test func homeRedirectsToDefaultRoom() async throws {
    try await withWeb { client, _ in
        let res = try await client.get("/")
        #expect(res.status == .seeOther)
        let location = res.headers[.location] ?? ""
        #expect(location.hasPrefix("/rooms/"))
    }
}

@Test func homeUsesPlatformAssetsNotCdn() async throws {
    try await withWeb { client, store in
        let room = store.ensureDefault(userID: openUserID)
        let res = try await client.get("rooms/\(room.id)")
        let text = try await html(res)
        #expect(res.status == .ok)
        #expect(text.contains("/static/platform/"))
        #expect(!text.contains("cdn.jsdelivr.net"))
        #expect(!text.contains("unpkg.com"))
        #expect(text.contains("PlnFlr"))
        #expect(text.contains("Pokój 1"))
    }
}

@Test func homeHasLayoutForm() async throws {
    try await withWeb { client, store in
        let room = store.ensureDefault(userID: openUserID)
        let text = try await html(try await client.get("rooms/\(room.id)"))
        #expect(text.contains("Rozłóż podłogę"))
        #expect(text.contains("hx-post=\"/rooms/"))
        #expect(text.contains("name=\"angle_deg\""))
        #expect(text.contains("Podziałka"))
        #expect(text.contains("name=\"hole_rectangles\""))
        #expect(text.contains("name=\"hole_vertices\""))
        #expect(!text.contains("Silnik rozkładu jest w kolejce"))
    }
}

@Test func homeUsesRangeSliders() async throws {
    try await withWeb { client, store in
        let room = store.ensureDefault(userID: openUserID)
        let text = try await html(try await client.get("rooms/\(room.id)"))
        #expect(text.contains("id=\"angle_deg\""))
        #expect(text.contains("type=\"range\""))
        #expect(text.contains("id=\"expansion_auto\""))
        #expect(text.contains("into_window"))
        #expect(text.contains("Prostopadle do okna"))
        #expect(text.contains("mapDeg"))
        #expect(text.contains("Obrót mapy"))
    }
}

@Test func createRoomFromForm() async throws {
    try await withWeb { client, store in
        let res = try await client.post("rooms", content: NewRoomPost(name: "Łazienka"))
        #expect(res.status == .seeOther)
        let location = res.headers[.location] ?? ""
        #expect(location.hasPrefix("/rooms/"))
        let id = location.split(separator: "/").last.map(String.init) ?? ""
        let created = store.get(id, userID: openUserID)
        #expect(created?.name == "Łazienka")
    }
}

@Test func twoRoomsAreIndependent() async throws {
    try await withWeb { client, store in
        let first = store.create(userID: openUserID, name: "Salon")
        let second = store.create(userID: openUserID, name: "Kuchnia", form: ["width_m": "5.500", "height_m": "2.400"])
        let salon = try await html(try await client.get("rooms/\(first.id)"))
        let kuchnia = try await html(try await client.get("rooms/\(second.id)"))
        #expect(salon.contains("Salon"))
        #expect(salon.contains("value=\"4.000\""))
        #expect(kuchnia.contains("Kuchnia"))
        #expect(kuchnia.contains("value=\"5.500\""))
        #expect(kuchnia.contains("hx-post=\"/rooms/\(second.id)/plan\""))
    }
}

@Test func planRectangleReturnsSvgAndRow() async throws {
    try await withWeb { client, _ in
        let res = try await client.post("plan", content: LayoutPost())
        let text = try await html(res)
        #expect(res.status == .ok)
        #expect(text.contains("<svg"))
        #expect(text.contains("Rząd 1"))
        #expect(text.contains("Paczek"))
    }
}

@Test func planWithHoleExcludesHoleFromSvgAndBom() async throws {
    try await withWeb { client, _ in
        var form = LayoutPost()
        form.kind = "tile"
        form.width_m = "4"
        form.height_m = "3"
        form.hole_rectangles = "1,1,1,1"
        form.tile_length_m = "1"
        form.tile_width_m = "1"
        form.grout_mm = "1"
        form.expansion_mm = "1"
        let res = try await client.post("plan", content: form)
        let text = try await html(res)
        #expect(res.status == .ok)
        #expect(text.contains("<svg"))
        #expect(text.contains("10.982 m²"))
        #expect(text.contains("M 1000 1000 L 2000 1000 L 2000 2000 L 1000 2000 Z"))
    }
}

@Test func planSplitReturnsTwoZones() async throws {
    try await withWeb { client, _ in
        var form = LayoutPost()
        form.split = "x"
        form.split_at_m = "2.000"
        let res = try await client.post("plan", content: form)
        let text = try await html(res)
        #expect(res.status == .ok)
        #expect(text.contains("pln-divider"))
        #expect(text.contains("Strefa A"))
        #expect(text.contains("Strefa B"))
    }
}

@Test func planLShapeReturnsSvg() async throws {
    try await withWeb { client, _ in
        var form = LayoutPost()
        form.shape = "l"
        let res = try await client.post("plan", content: form)
        let text = try await html(res)
        #expect(res.status == .ok)
        #expect(text.contains("<svg"))
        #expect(text.contains("Rząd 1"))
    }
}

@Test func planPolygonFromOriginReturnsSvg() async throws {
    try await withWeb { client, _ in
        var form = LayoutPost()
        form.shape = "polygon"
        form.vertices = "0,0\n4,0\n4,3\n0,3"
        let res = try await client.post("plan", content: form)
        let text = try await html(res)
        #expect(res.status == .ok)
        #expect(text.contains("<svg"))
        #expect(!text.contains("metres must be positive"))
    }
}

@Test func planBowtieReturns400() async throws {
    try await withWeb { client, _ in
        var form = LayoutPost()
        form.shape = "polygon"
        form.vertices = "1,1\n2,2\n2,1\n1,2"
        let res = try await client.post("plan", content: form)
        let text = try await html(res).lowercased()
        #expect(res.status == .badRequest)
        #expect(text.contains("self-intersecting") || text.contains("wielokąt"))
        #expect(!text.contains("<svg"))
    }
}

@Test func planExplicitZeroExpansionIsNoGap() async throws {
    try await withWeb { client, _ in
        var form = LayoutPost()
        form.expansion_mm = "0"
        let res = try await client.post("plan", content: form)
        let text = try await html(res)
        #expect(res.status == .ok)
        #expect(text.contains("<svg"))
        #expect(text.contains(">0 mm<"))
    }
}
