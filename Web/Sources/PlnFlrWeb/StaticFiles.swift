import Foundation
import HTTPTypes
import NIOCore
import Vapor

struct StaticFileMiddleware: Middleware {
    let publicDirectory: String

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        guard request.method == .get || request.method == .head else {
            return try await next.respond(to: request)
        }
        guard var path = request.url.path.removingPercentEncoding else {
            throw Abort(.badRequest)
        }
        while path.hasPrefix("/") { path.removeFirst() }
        guard path.hasPrefix("static/"), !path.contains("..") else {
            return try await next.respond(to: request)
        }
        let file = URL(fileURLWithPath: publicDirectory).appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file)
        else {
            return try await next.respond(to: request)
        }
        let body = Response.Body(data: data)
        var headers = HTTPFields()
        headers.contentType = mediaType(for: file.pathExtension)
        return Response(status: .ok, headers: headers, body: body)
    }
}

private func mediaType(for ext: String) -> HTTPMediaType {
    switch ext.lowercased() {
    case "css": .css
    case "js": .init(type: "text", subType: "javascript")
    case "svg": .init(type: "image", subType: "svg+xml")
    case "png": .png
    default: .init(type: "application", subType: "octet-stream")
    }
}
