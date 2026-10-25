import CustomDump
import Foundation
import PlnFlrLayout
import Testing
@testable import PlnFlrCapture

@Test func importedUsdzIsPreservedInDurableWorkspaceArchive() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = WorkspaceStorage(url: directory.appendingPathComponent("workspace.json"))
    let sourceUsdz = twoFloorUsdz()
    let captured = try roomFromUsdz(sourceUsdz)
    let scan = Workspace.Scan.State(
        id: UUID(),
        label: "Skan źródłowy",
        rooms: captured.rooms,
        sourceUsdz: sourceUsdz
    )
    let project = Workspace.Project.State(id: UUID(), name: "Dom", scans: [scan])
    let state = Workspace.State(projects: [project], selectedProjectID: project.id)

    try storage.save(WorkspaceArchive(state))

    let restored = try storage.load().state
    #expect(restored.projects[0].scans[0].sourceUsdz == sourceUsdz)
    #expect(restored.projects[0].scans[0].rooms == captured.rooms)
}

@Test func workspaceSaveAtomicallyReplacesArchiveGeneration() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("workspace.json")
    let storage = WorkspaceStorage(url: url)
    let originalProject = Workspace.Project.State(id: UUID(), name: "Pierwotny dom")
    try storage.save(WorkspaceArchive(Workspace.State(projects: [originalProject], selectedProjectID: originalProject.id)))

    let originalBytes = try Data(contentsOf: url)
    let originalGeneration = try FileHandle(forReadingFrom: url)
    defer { try? originalGeneration.close() }
    let replacementProject = Workspace.Project.State(id: UUID(), name: "Zmieniony dom")
    try storage.save(WorkspaceArchive(Workspace.State(projects: [replacementProject], selectedProjectID: replacementProject.id)))

    try originalGeneration.seek(toOffset: 0)
    #expect(try originalGeneration.readToEnd() == originalBytes)
    #expect(try storage.load().projects[0].name == "Zmieniony dom")
    #expect(try Data(contentsOf: url) != originalBytes)
}

@Test func workspaceSurvivesDiskRoundTrip() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = WorkspaceStorage(url: directory.appendingPathComponent("workspace.json"))
    let captured = try roomFromUsdz(twoFloorUsdz())
    let floor = Workspace.Floor.State(id: UUID(), name: "Salon", room: captured.rooms[0].room,
                                     thresholds: captured.rooms[0].thresholds, windows: captured.rooms[0].windows)
    let sourceUsdz = twoFloorUsdz()
    let project = Workspace.Project.State(id: UUID(), name: "Dom", scans: [
        .init(id: UUID(), label: "Parter", rooms: captured.rooms, sourceUsdz: sourceUsdz)
    ], floors: [floor], selectedFloorIDs: [floor.id])
    let state = Workspace.State(projects: [project], selectedProjectID: project.id)
    try storage.save(WorkspaceArchive(state))
    let restored = try storage.load().state
    expectNoDifference(restored.projects, state.projects)
    expectNoDifference(restored.selectedProjectID, state.selectedProjectID)
    expectNoDifference(restored.projects[0].scans[0].sourceUsdz, sourceUsdz)
}
