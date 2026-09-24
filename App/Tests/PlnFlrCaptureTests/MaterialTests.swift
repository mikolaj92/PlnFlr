import ComposableArchitecture2
import CustomDump
import Foundation
import PlnFlrLayout
import Testing
@testable import PlnFlrCapture

@Test func finishSelectionPersistsWithoutChangingMeasuredMaterialQuantities() throws {
    let oak = Workspace.Floor.State(id: UUID(), name: "Salon", room: try rectangle(widthMm: 4000, heightMm: 3000))
    var walnut = oak
    walnut.finish = .walnut
    let oakPlan = try oak.makePlan()
    let walnutPlan = try walnut.makePlan()
    expectNoDifference(walnutPlan.bom, oakPlan.bom)
    expectNoDifference(walnutPlan.pieces, oakPlan.pieces)

    let archive = WorkspaceArchive(Workspace.State(projects: [.init(id: UUID(), name: "Dom", floors: [walnut])]))
    let decoded = try JSONDecoder().decode(WorkspaceArchive.self, from: JSONEncoder().encode(archive))
    #expect(decoded.state.projects[0].floors[0].finish == .walnut)
}

@Test func invalidMaterialEditReplacesOldQuantityPlanWithAnError() async throws {
    var floor = Workspace.Floor.State(id: UUID(), name: "Salon", room: try rectangle(widthMm: 4000, heightMm: 3000))
    floor.plan = try floor.makePlan()
    let store = await TestStoreActor(initialState: floor) { Workspace.Floor() }
    await store.modify { $0.plankLengthM = "0" } changes: {
        $0.plan = nil
        $0.error = MaterialInputError.invalid.localizedDescription
    }
}

@Test func newFinishDefaultsToOakForOlderProjectArchives() throws {
    let floor = Workspace.Floor.State(id: UUID(), name: "Salon", room: try rectangle(widthMm: 4000, heightMm: 3000))
    let current = WorkspaceArchive(Workspace.State(projects: [.init(id: UUID(), name: "Dom", floors: [floor])]))
    let json = String(decoding: try JSONEncoder().encode(current), as: UTF8.self)
    let legacyJSON = json.replacingOccurrences(of: ",\"finish\":\"oak\"", with: "")
    let archive = try JSONDecoder().decode(WorkspaceArchive.self, from: Data(legacyJSON.utf8))
    #expect(archive.state.projects[0].floors[0].finish == .oak)
}

@Test func finishChangesKeepTheMeasuredLayoutVisible() async throws {
    var floor = Workspace.Floor.State(id: UUID(), name: "Salon", room: try rectangle(widthMm: 4000, heightMm: 3000))
    floor.plan = try floor.makePlan()
    let store = await TestStoreActor(initialState: floor) { Workspace.Floor() }
    await store.modify { $0.finish = .walnut } changes: { $0.finish = .walnut }
}

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

@Test func changingMaterialInputsRecalculatesVisiblePlanAndQuantities() async throws {
    var floor = Workspace.Floor.State(id: UUID(), name: "Salon", room: try rectangle(widthMm: 4000, heightMm: 3000))
    floor.plan = try floor.makePlan()
    var updated = floor
    updated.plankWidthM = "0.2"
    let expectedPlan = try updated.makePlan()
    #expect(expectedPlan.bom.pieces != floor.plan?.bom.pieces)

    let store = await TestStoreActor(initialState: floor) { Workspace.Floor() }
    await store.modify { $0.plankWidthM = "0.2" } changes: {
        $0.plan = expectedPlan
        $0.error = nil
    }
}
