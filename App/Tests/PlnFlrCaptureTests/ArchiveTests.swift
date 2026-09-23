import CustomDump
import Foundation
import PlnFlrLayout
import Testing
@testable import PlnFlrCapture

@Test func workspaceSurvivesDiskRoundTrip() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = WorkspaceStorage(url: directory.appendingPathComponent("workspace.json"))
    let captured = try roomFromUsdz(twoFloorUsdz())
    let floor = Workspace.Floor.State(id: UUID(), name: "Salon", room: captured.rooms[0].room,
                                     thresholds: captured.rooms[0].thresholds, windows: captured.rooms[0].windows)
    let project = Workspace.Project.State(id: UUID(), name: "Dom", scans: [
        .init(id: UUID(), label: "Parter", rooms: captured.rooms)
    ], floors: [floor], selectedFloorIDs: [floor.id])
    let state = Workspace.State(projects: [project], selectedProjectID: project.id)
    try storage.save(WorkspaceArchive(state))
    let restored = try storage.load().state
    expectNoDifference(restored.projects, state.projects)
    expectNoDifference(restored.selectedProjectID, state.selectedProjectID)
}
