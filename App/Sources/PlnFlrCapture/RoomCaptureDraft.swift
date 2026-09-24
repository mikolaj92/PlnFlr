import Foundation

/// Room-to-room capture lifecycle. Apple owns geometry and shared AR coordinates.
struct RoomCaptureDraft {
    enum Phase: Equatable {
        case scanning, processing, reviewing, building, closed
    }
    private(set) var phase = Phase.scanning
    private(set) var rooms: [Data] = []

    mutating func finishRoom() -> Bool {
        guard phase == .scanning else { return false }
        phase = .processing
        return true
    }

    mutating func acceptRoom(_ source: Data) -> Bool {
        guard phase == .processing, !source.isEmpty else { return false }
        rooms.append(source)
        phase = .reviewing
        return true
    }

    mutating func nextRoom() -> Bool {
        guard phase == .reviewing else { return false }
        phase = .scanning
        return true
    }

    mutating func close() {
        phase = .closed
    }

    mutating func buildFailed() {
        guard phase == .building else { return }
        phase = .reviewing
    }

    mutating func beginSave() -> Bool {
        guard phase == .reviewing else { return false }
        phase = .building
        return true
    }
}
