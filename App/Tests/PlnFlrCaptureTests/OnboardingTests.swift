import ComposableArchitecture2
import Foundation
import PlnFlrLayout
import Testing
@testable import PlnFlrCapture

@Test func manualRoomStartsFirstProject() async throws {
    let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let floorID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let room = try rectangle(widthMm: 4000, heightMm: 3000)
    var state = Workspace.State()
    state.isAddingRoom = true
    let store = await TestStoreActor(initialState: state) { Workspace() }
    await store.send(.addRoomButtonTapped) {
        $0.projects = [snap(Workspace.Project.State(id: projectID, name: "Projekt 1", floors: [
            .init(id: floorID, name: "Pokój", room: room)
        ], selectedFloorIDs: [floorID]))]
        $0.selectedProjectID = projectID
        $0.isAddingRoom = false
    }
}

@Test func invalidManualRoomDoesNotCreateProject() async {
    var state = Workspace.State()
    state.manualWidthM = "0"
    let store = await TestStoreActor(initialState: state) { Workspace() }
    await store.send(.addRoomButtonTapped) {
        $0.manualRoomError = "Wymiary pokoju muszą wynosić od 0,1 do 100 m."
    }
}

@Test func failedScanDoesNotCreateEmptyProject() async {
    let store = await TestStoreActor(initialState: Workspace.State()) { Workspace() }
    await store.send(.importUsdz(Data())) {
        $0.error = ScanError.notZip.localizedDescription
    }
}
