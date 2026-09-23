import ComposableArchitecture2
import CustomDump
import Foundation
import PlnFlrLayout
import Testing
@testable import PlnFlrCapture

@Test func tileSettingsAreUsedAndPersisted() throws {
    var floor = Workspace.Floor.State(id: UUID(), name: "Łazienka", room: try rectangle(widthMm: 4000, heightMm: 3000))
    floor.material = .tile
    floor.plankLengthM = "0.600"
    floor.plankWidthM = "0.600"
    floor.packSize = "4"
    floor.groutMm = "2"
    let expected = try layoutFloor(floor.room, zones: [.init(kind: .tile, tile: .init(lengthMm: 600, widthMm: 600, groutMm: 2, tilesPerPack: 4))], rules: .init(expansionMm: 10))
    expectNoDifference(try floor.makePlan(), expected)
    let archive = WorkspaceArchive(Workspace.State(projects: [.init(id: UUID(), name: "Dom", floors: [floor])]))
    let decoded = try JSONDecoder().decode(WorkspaceArchive.self, from: JSONEncoder().encode(archive))
    expectNoDifference(decoded.state.projects[0].floors[0], floor)
}

@Test func enormousLayoutIsRejectedBeforeAllocatingMillionsOfPieces() throws {
    var floor = Workspace.Floor.State(id: UUID(), name: "Hala", room: try rectangle(widthMm: 100_000, heightMm: 100_000))
    floor.plankWidthM = "0.05"
    floor.plankLengthM = "0.05"
    #expect(throws: MaterialInputError.tooManyPieces) { try floor.makePlan() }
}

@Test func changingMaterialInputsClearsStalePreview() async throws {
    var floor = Workspace.Floor.State(id: UUID(), name: "Salon", room: try rectangle(widthMm: 4000, heightMm: 3000))
    floor.plan = try floor.makePlan()
    let store = await TestStoreActor(initialState: floor) { Workspace.Floor() }
    await store.modify { $0.plankWidthM = "0.2" } changes: { $0.plan = nil }
}
