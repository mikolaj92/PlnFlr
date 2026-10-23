import ComposableArchitecture2
import CustomDump
import Foundation
import PlnFlrLayout
import Testing
@testable import PlnFlrCapture

@Test func launchRestoresWorkspaceAndSavesBindingChanges() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = WorkspaceStorage(url: directory.appendingPathComponent("workspace.json"))
    let project = Workspace.Project.State(id: UUID(), name: "Dom")
    try storage.save(WorkspaceArchive(Workspace.State(projects: [project], selectedProjectID: project.id)))
    let store = await TestStoreActor(initialState: Workspace.State()) {
        Workspace().environment(\.workspaceFiles, WorkspaceFiles(load: { try storage.load() }, save: { try storage.save($0) }))
    }
    await store.send(.appStarted) {
        $0.projects = [snap(project)]
        $0.selectedProjectID = project.id
        $0.hasLoaded = true
    }
    await store.modify { $0.projects[0].name = "Mój dom" }
    expectNoDifference(try storage.load().state.projects[0].name, "Mój dom")
}

@Test func corruptArchiveIsNotOverwrittenByAutosave() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let storage = WorkspaceStorage(url: directory.appendingPathComponent("workspace.json"))
    let original = Data("not json".utf8)
    try original.write(to: storage.url)
    let store = await TestStoreActor(initialState: Workspace.State()) {
        Workspace().environment(\.workspaceFiles, WorkspaceFiles(load: { try storage.load() }, save: { try storage.save($0) }))
    }
    await store.send(.appStarted) {
        $0.storageError = Workspace.loadFailureMessage
    }
    await store.send(.newProjectButtonTapped)
    expectNoDifference(try Data(contentsOf: storage.url), original)
}
