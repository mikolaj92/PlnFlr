import ComposableArchitecture2
import CustomDump
import Foundation
import Testing
@testable import PlnFlrCapture

@Test func completedCameraScanIsSavedWithoutConsumingFreeRoom() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = WorkspaceStorage(url: directory.appendingPathComponent("workspace.json"))
    var state = Workspace.State()
    state.hasLoaded = true
    let store = await TestStoreActor(initialState: state) {
        Workspace().environment(\.workspaceFiles, WorkspaceFiles(load: { try storage.load() }, save: { try storage.save($0) }))
    }
    let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let scanID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    // Opaque adapter output: this tests storage, not Apple's geometry schema.
    let source = Data("{\"walls\":[],\"identifier\":\"test-source\"}".utf8)
    await store.send(.scanRoomButtonTapped) { $0.isCapturingRoom = true }
    await store.send(.roomCaptureFinished(source)) {
        $0.isCapturingRoom = false
        $0.projects = [snap(Workspace.Project.State(id: projectID, name: "Projekt 1", scans: [
            .init(id: scanID, label: "Skan 1", rooms: [], roomPlanJSON: source)
        ]))]
        $0.selectedProjectID = projectID
    }
    let restored = try storage.load().state
    expectNoDifference(restored.projects[0].scans[0].roomPlanJSON, source)
    #expect(restored.freeRoomID == nil)
    #expect(restored.projects[0].floors.isEmpty)
}

@Test func completedStructurePreservesAllSourcesAcrossReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = WorkspaceStorage(url: directory.appendingPathComponent("workspace.json"))
    let projectID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    let scanID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    var state = Workspace.State(projects: [.init(id: projectID, name: "Dom")], selectedProjectID: projectID)
    state.hasLoaded = true
    let store = await TestStoreActor(initialState: state) {
        Workspace().environment(\.workspaceFiles, WorkspaceFiles(load: { try storage.load() }, save: { try storage.save($0) }))
    }
    // Opaque adapter bytes, not a fabricated Apple geometry fixture.
    let source = RoomPlanStructureSource(rooms: [Data("kitchen".utf8), Data("hall".utf8)], structure: Data("assembled".utf8))
    await store.send(.scanRoomButtonTapped) { $0.isCapturingRoom = true }
    await store.send(.structureCaptureFinished(source)) {
        $0.isCapturingRoom = false
        $0.projects[0].scans = [snap(Workspace.Scan.State(id: scanID, label: "Skan 1", rooms: [], roomPlanStructure: source))]
    }
    let restored = try storage.load().state
    expectNoDifference(restored.projects[0].scans[0].roomPlanStructure, source)
    #expect(restored.freeRoomID == nil)
    #expect(!restored.hasPro)
    #expect(restored.projects[0].floors.isEmpty)
    #expect(restored.projects[0].scans[0].roomPlanJSON == nil)
}

@Test func captureCancelIgnoresLateResult() async {
    let store = await TestStoreActor(initialState: Workspace.State()) { Workspace() }
    await store.send(.scanRoomButtonTapped) { $0.isCapturingRoom = true }
    await store.send(.roomCaptureCancelled) { $0.isCapturingRoom = false }
    await store.send(.roomCaptureFinished(Data("late".utf8)))
    await store.send(.roomCaptureFailed("late failure"))
    await store.send(.structureCaptureFinished(.init(rooms: [Data("late".utf8)], structure: Data("late".utf8))))
}

@Test func captureFailureLeavesProjectUntouched() async {
    let store = await TestStoreActor(initialState: Workspace.State()) { Workspace() }
    await store.send(.scanRoomButtonTapped) { $0.isCapturingRoom = true }
    await store.send(.roomCaptureFailed("Brak dostępu do aparatu.")) {
        $0.isCapturingRoom = false
        $0.error = "Brak dostępu do aparatu."
    }
}

@Test func damagedArchiveBlocksCameraCapture() async {
    var state = Workspace.State()
    state.storageError = Workspace.loadFailureMessage
    let store = await TestStoreActor(initialState: state) { Workspace() }
    await store.send(.scanRoomButtonTapped)
    await store.send(.roomCaptureFinished(Data("late".utf8)))
    await store.send(.structureCaptureFinished(.init(rooms: [Data("late".utf8)], structure: Data("late".utf8))))
}

@Test func emptyStructureDoesNotCreateProject() async {
    for source in [
        RoomPlanStructureSource(rooms: [], structure: Data("structure".utf8)),
        RoomPlanStructureSource(rooms: [Data()], structure: Data("structure".utf8)),
        RoomPlanStructureSource(rooms: [Data("room".utf8)], structure: Data())
    ] {
        let store = await TestStoreActor(initialState: Workspace.State()) { Workspace() }
        await store.send(.scanRoomButtonTapped) { $0.isCapturingRoom = true }
        await store.send(.structureCaptureFinished(source)) {
            $0.isCapturingRoom = false
            $0.error = "Skan jest pusty. Spróbuj ponownie."
        }
    }
}

@Test func emptyCaptureDoesNotCreateProject() async {
    let store = await TestStoreActor(initialState: Workspace.State()) { Workspace() }
    await store.send(.scanRoomButtonTapped) { $0.isCapturingRoom = true }
    await store.send(.roomCaptureFinished(Data())) {
        $0.isCapturingRoom = false
        $0.error = "Skan jest pusty. Spróbuj ponownie."
    }
}

@Test func oldArchiveWithoutCameraSourceStillLoads() throws {
    let project = Workspace.Project.State(id: UUID(), name: "Dom", scans: [
        .init(id: UUID(), label: "Stary skan", rooms: [])
    ])
    let encoded = try JSONEncoder().encode(WorkspaceArchive(Workspace.State(projects: [project])))
    // Optional source must stay absent in old archives; no fabricated replacement.
    #expect(!String(decoding: encoded, as: UTF8.self).contains("roomPlanJSON"))
    let decoded = try JSONDecoder().decode(WorkspaceArchive.self, from: encoded)
    expectNoDifference(decoded.state.projects, [project])
}
