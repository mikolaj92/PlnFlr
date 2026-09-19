import Foundation
import HTTPTypes
import PlnFlrLayout
import Vapor

struct NewRoomForm: Content {
    var name: String = ""
}

struct ScanForm: Content {
    var scan: File
}

func registerRoutes(_ app: Application, rooms: RoomStore, scanMaxBytes: Int = defaultScanMaxBytes) {
    app.get("healthz") { _ in Health(ok: "plnflr") }

    app.get { req in
        let room = rooms.ensureDefault(userID: openUserID)
        return redirect(req, to: "/rooms/\(room.id)")
    }

    app.get("rooms", "new") { _ in
        htmlResponse(newRoomPage(rooms: rooms.list(userID: openUserID)))
    }

    app.post("rooms") { req in
        let form = (try? await req.content.decode(NewRoomForm.self)) ?? NewRoomForm()
        let room = rooms.create(userID: openUserID, name: form.name)
        return redirect(req, to: "/rooms/\(room.id)")
    }

    app.get("rooms", ":id") { req -> Response in
        let id = req.parameters.get("id") ?? ""
        guard let room = rooms.get(id, userID: openUserID) else {
            return redirect(req, to: "/")
        }
        var form = defaultForm()
        form.merge(room.form) { _, new in new }
        return htmlResponse(
            roomPage(
                room: room,
                rooms: rooms.list(userID: openUserID),
                form: form,
                scanMaxBytes: scanMaxBytes
            )
        )
    }

    app.on(.post, "rooms", ":id", "scan", maxBodySize: ByteCount(value: scanMaxBytes + 64 * 1024)) { req -> Response in
        let id = req.parameters.get("id") ?? ""
        guard let saved = rooms.get(id, userID: openUserID) else {
            return redirect(req, to: "/")
        }
        do {
            let upload = try await req.content.decode(ScanForm.self)
            let payload = Data(buffer: upload.scan.data)
            if payload.count > scanMaxBytes {
                return htmlResponse(errorFragment("Skan jest za duży."), status: .contentTooLarge)
            }
            let captured = try roomFromUsdz(payload)
            var form = defaultForm()
            form.merge(saved.form) { _, new in new }
            form["shape"] = "polygon"
            form["vertices"] = captured.verticesM
            form["hole_rectangles"] = captured.holeRectangles
            form["hole_vertices"] = ""
            form["door_rectangles"] = ""
            form["door_vertices"] = captured.doorVertices
            form["window_segments"] = captured.windowSegments
            rooms.updateForm(id, userID: openUserID, form: form)
            return redirect(req, to: "/rooms/\(saved.id)")
        } catch let error as ScanError where error == .tooLarge {
            return htmlResponse(errorFragment("Skan jest za duży."), status: .contentTooLarge)
        } catch is DecodingError {
            return htmlResponse(errorFragment("Skan jest za duży."), status: .contentTooLarge)
        } catch {
            return htmlResponse(errorFragment(error.localizedDescription), status: .badRequest)
        }
    }

    app.post("rooms", ":id", "plan") { req -> Response in
        let id = req.parameters.get("id") ?? ""
        return await planResponse(req, rooms: rooms, roomID: id)
    }

    app.post("plan") { req -> Response in
        let room = rooms.ensureDefault(userID: openUserID)
        return await planResponse(req, rooms: rooms, roomID: room.id)
    }
}

private func planResponse(_ req: Request, rooms: RoomStore, roomID: String) async -> Response {
    guard rooms.get(roomID, userID: openUserID) != nil else {
        return htmlResponse(errorFragment("Nie ma takiego pokoju."), status: .notFound)
    }
    do {
        let form = try await req.content.decode(LayoutForm.self)
        let laid = try layoutFromForm(form)
        rooms.updateForm(roomID, userID: openUserID, form: form.asDict())
        return htmlResponse(planFragment(laid))
    } catch {
        return htmlResponse(errorFragment(error.localizedDescription), status: .badRequest)
    }
}

func htmlResponse(_ html: String, status: HTTPResponse.Status = .ok) -> Response {
    var headers = HTTPFields()
    headers.contentType = .html
    return Response(status: status, headers: headers, body: .init(string: html))
}

func redirect(_ req: Request, to location: String) -> Response {
    var response = req.redirect(to: location, redirectType: .normal)
    if req.headers[HTTPField.Name("HX-Request")!] == "true" {
        response.headers[HTTPField.Name("HX-Redirect")!] = location
    }
    return response
}
