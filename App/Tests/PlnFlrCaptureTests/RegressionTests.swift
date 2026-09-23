import ComposableArchitecture2
import CustomDump
import Foundation
import PlnFlrLayout
import Testing
@testable import PlnFlrCapture

@Test func freeRoomSurvivesRestartButProNeverComesFromDisk() throws {
    var state = Workspace.State()
    state.freeRoomID = UUID()
    state.hasPro = true
    let archive = try JSONDecoder().decode(WorkspaceArchive.self, from: JSONEncoder().encode(WorkspaceArchive(state)))
    expectNoDifference(archive.state.freeRoomID, state.freeRoomID)
    #expect(!archive.state.hasPro)
}

@Test func missingFileStartsEmptyAndFutureVersionIsRejected() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let files = WorkspaceStorage(url: directory.appendingPathComponent("workspace.json"))
    #expect(try files.load().projects.isEmpty)
    var future = WorkspaceArchive(Workspace.State())
    future.version = 999
    try files.save(future)
    #expect(throws: ArchiveError.self) { try files.load() }
}

@Test func splitKeepsFreeAccessAndMaterialSettings() async throws {
    var floor = Workspace.Floor.State(id: UUID(), name: "Salon", room: try rectangle(widthMm: 4000, heightMm: 3000), plankWidthM: "0.200")
    floor.material = .tile
    floor.groutMm = "2"
    floor.packSize = "4"
    let project = Workspace.Project.State(id: UUID(), name: "Dom", floors: [floor], selectedFloorIDs: [floor.id])
    var state = Workspace.State(projects: [project], selectedProjectID: project.id)
    state.freeRoomID = floor.id
    let store = await TestStoreActor(initialState: state) { Workspace() }
    let parts = try splitRoom(floor.room, axis: .x, atMm: 1500)
    var first = Workspace.Floor.State(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Salon A", room: parts.0!, plankWidthM: "0.200", accessID: floor.id)
    first.material = .tile
    first.groutMm = "2"
    first.packSize = "4"
    var second = first
    second.floorID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    second.name = "Salon B"
    second.room = parts.1!
    await store.send(.splitSelectedButtonTapped) {
        $0.projects[0].floors = [snap(first), snap(second)]
        $0.projects[0].selectedFloorIDs = [first.id]
    }
    let expected = try second.makePlan()
    await store.send(.planFloorButtonTapped(project.id, second.id)) {
        $0.projects[0].floors[1].plan = expected
    }
}

@Test func saveFailureRetainsEditsAndCanBeRetried() async {
    struct Failure: Error {}
    let project = Workspace.Project.State(id: UUID(), name: "Dom")
    let files = WorkspaceFiles(load: { WorkspaceArchive(Workspace.State(projects: [project])) }, save: { _ in throw Failure() })
    let store = await TestStoreActor(initialState: Workspace.State()) { Workspace().environment(\.workspaceFiles, files) }
    await store.send(.appStarted) {
        $0.projects = [snap(project)]
        $0.hasLoaded = true
        $0.storageError = "Nie udało się zapisać projektów: \(Failure().localizedDescription)"
    }
    await store.modify { $0.projects[0].name = "Zmieniony projekt" }
    await store.send(.retrySaveButtonTapped)
}

@Test func purchasesCanRefreshWhileProjectRecoveryIsBlocked() async {
    var state = Workspace.State()
    state.storageError = Workspace.loadFailureMessage
    let client = PurchaseClient(product: { nil }, purchase: { .cancelled }, restore: { false }, currentAccess: { true }, updates: { AsyncStream { $0.finish() } })
    let store = await TestStoreActor(initialState: state) { Workspace().environment(\.purchases, client) }
    await store.send(.refreshAccess)
    await store.receive(\.proAccessChanged) { $0.hasPro = true }
}

@Test func productReloadAndForegroundAccessRefresh() async {
    let client = PurchaseClient(product: { .init(displayPrice: "49,99 zł") }, purchase: { .cancelled }, restore: { false }, currentAccess: { true }, updates: { AsyncStream { $0.finish() } })
    let store = await TestStoreActor(initialState: Workspace.State()) { Workspace().environment(\.purchases, client) }
    await store.send(.reloadProductButtonTapped)
    await store.receive(\.storeProductLoaded) { $0.proProduct = .init(displayPrice: "49,99 zł") }
    await store.send(.refreshAccess)
    await store.receive(\.proAccessChanged) { $0.hasPro = true }
}
