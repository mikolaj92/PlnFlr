import Foundation
import Vapor

public let defaultScanMaxBytes = 8 * 1024 * 1024

public func configure(_ app: Application) async throws {
    try await configure(app, rooms: RoomStore.live())
}

public func configure(
    _ app: Application,
    rooms: RoomStore,
    scanMaxBytes: Int = defaultScanMaxBytes
) async throws {
    let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "") ?? 8004
    app.serverConfiguration.address = .hostname("0.0.0.0", port: port)
    app.middleware.use(StaticFileMiddleware(publicDirectory: publicRoot()))
    registerRoutes(app, rooms: rooms, scanMaxBytes: scanMaxBytes)
}

func publicRoot() -> String {
    let cwd = FileManager.default.currentDirectoryPath
    let candidates = [
        cwd + "/Public",
        cwd + "/Web/Public",
    ]
    return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? (cwd + "/Public")
}
