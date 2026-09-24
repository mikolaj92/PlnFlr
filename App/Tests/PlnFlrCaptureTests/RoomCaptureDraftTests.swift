import CustomDump
import Foundation
import Testing
@testable import PlnFlrCapture

@Test func captureDraftRejectsOutOfOrderAndDuplicateCallbacks() {
    var draft = RoomCaptureDraft()
    let source = Data("room".utf8)
    #expect(draft.beginSave() == false)
    #expect(draft.nextRoom() == false)
    #expect(draft.acceptRoom(source) == false)
    #expect(draft.finishRoom() == true)
    #expect(draft.finishRoom() == false)
    #expect(draft.acceptRoom(Data()) == false)
    expectNoDifference(draft.phase, .processing)
    #expect(draft.acceptRoom(source) == true)
    #expect(draft.acceptRoom(source) == false)
    #expect(draft.beginSave() == true)
    #expect(draft.beginSave() == false)
    #expect(draft.nextRoom() == false)
    expectNoDifference(draft.rooms, [source])
}

@Test func structureBuildFailureAllowsRetryWithoutLosingRooms() {
    var draft = RoomCaptureDraft()
    let source = Data("room".utf8)
    _ = draft.finishRoom()
    _ = draft.acceptRoom(source)
    _ = draft.beginSave()
    draft.buildFailed()
    expectNoDifference(draft.phase, .reviewing)
    expectNoDifference(draft.rooms, [source])
    #expect(draft.beginSave() == true)
}

@Test func closedDraftIgnoresLateCallbacks() {
    var draft = RoomCaptureDraft()
    _ = draft.finishRoom()
    draft.close()
    #expect(draft.acceptRoom(Data("late".utf8)) == false)
    #expect(draft.finishRoom() == false)
    #expect(draft.nextRoom() == false)
    #expect(draft.beginSave() == false)
    draft.buildFailed()
    expectNoDifference(draft.phase, .closed)
    #expect(draft.rooms.isEmpty)
}

@Test func captureDraftCollectsRoomsBeforeBuildingOneStructure() {
    var draft = RoomCaptureDraft()
    let kitchen = Data("kitchen-source".utf8)
    let hall = Data("hall-source".utf8)
    #expect(draft.finishRoom() == true)
    #expect(draft.acceptRoom(kitchen) == true)
    expectNoDifference(draft.phase, .reviewing)
    #expect(draft.nextRoom() == true)
    #expect(draft.finishRoom() == true)
    #expect(draft.acceptRoom(hall) == true)
    #expect(draft.beginSave() == true)
    expectNoDifference(draft.phase, .building)
    expectNoDifference(draft.rooms, [kitchen, hall])
}
