import ComposableArchitecture2
import Foundation
import PlnFlrLayout
import Testing
@testable import PlnFlrCapture

@Test func firstSuccessfulPlanClaimsFreeRoomAndSecondShowsPaywall() async throws {
    let room = try rectangle(widthMm: 4000, heightMm: 3000)
    let first = Workspace.Floor.State(id: UUID(), name: "Salon", room: room)
    let second = Workspace.Floor.State(id: UUID(), name: "Sypialnia", room: room)
    let project = Workspace.Project.State(id: UUID(), name: "Dom", floors: [first, second])
    let expected = try layoutFloor(room, zones: [.init(kind: .plank, plank: .init(lengthMm: 1383, widthMm: 156, boardsPerPack: 8))], rules: .init(expansionMm: 10))
    let store = await TestStoreActor(initialState: Workspace.State(projects: [project])) { Workspace() }
    await store.send(.planFloorButtonTapped(project.id, first.id)) {
        $0.projects[0].floors[0].plan = expected
        $0.freeRoomID = first.id
    }
    await store.send(.planFloorButtonTapped(project.id, second.id)) {
        $0.isPaywallPresented = true
    }
    await store.send(.planFloorButtonTapped(project.id, first.id))
}

@Test func failedPlanDoesNotConsumeFreeRoom() async throws {
    var floor = Workspace.Floor.State(id: UUID(), name: "Salon", room: try rectangle(widthMm: 4000, heightMm: 3000))
    floor.expansionMm = "oops"
    let project = Workspace.Project.State(id: UUID(), name: "Dom", floors: [floor])
    let store = await TestStoreActor(initialState: Workspace.State(projects: [project])) { Workspace() }
    await store.send(.planFloorButtonTapped(project.id, floor.id)) {
        $0.projects[0].floors[0].error = MaterialInputError.invalid.localizedDescription
    }
}

@Test func proCanPlanSecondRoomAndRevocationLocksItWithoutDeletingInputs() async throws {
    let floor = Workspace.Floor.State(id: UUID(), name: "Salon", room: try rectangle(widthMm: 4000, heightMm: 3000))
    let project = Workspace.Project.State(id: UUID(), name: "Dom", floors: [floor])
    var state = Workspace.State(projects: [project])
    state.freeRoomID = UUID()
    let store = await TestStoreActor(initialState: state) { Workspace() }
    await store.send(.proAccessChanged(true)) { $0.hasPro = true }
    let expected = try layoutFloor(floor.room, zones: [.init(kind: .plank, plank: .init(lengthMm: 1383, widthMm: 156, boardsPerPack: 8))], rules: .init(expansionMm: 10))
    await store.send(.planFloorButtonTapped(project.id, floor.id)) {
        $0.projects[0].floors[0].plan = expected
    }
    await store.send(.proAccessChanged(false)) {
        $0.hasPro = false
        $0.projects[0].floors[0].plan = nil
    }
    await store.send(.planFloorButtonTapped(project.id, floor.id)) { $0.isPaywallPresented = true }
}
