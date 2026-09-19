import ComposableArchitecture2
import Foundation
import PlnFlrLayout

@Feature
public struct House {
    public struct RoomItem: Equatable, Identifiable, Sendable {
        public var id: UUID
        public var name: String
        public var room: Room
        public var thresholds: [Threshold]
        public var windows: [Opening]

        public init(
            id: UUID,
            name: String,
            room: Room,
            thresholds: [Threshold],
            windows: [Opening]
        ) {
            self.id = id
            self.name = name
            self.room = room
            self.thresholds = thresholds
            self.windows = windows
        }
    }

    public struct State {
        public var error: String?
        public var isImporting: Bool
        public var rooms: [RoomItem]
        public var selectedID: UUID?
        public var splitAtM: String
        public var splitAxis: SplitAxis

        public init(
            error: String? = nil,
            isImporting: Bool = false,
            rooms: [RoomItem] = [],
            selectedID: UUID? = nil,
            splitAtM: String = "1.500",
            splitAxis: SplitAxis = .x
        ) {
            self.error = error
            self.isImporting = isImporting
            self.rooms = rooms
            self.selectedID = selectedID
            self.splitAtM = splitAtM
            self.splitAxis = splitAxis
        }
    }

    public enum Action {
        case importUsdz(Data)
        case splitSelectedButtonTapped
    }

    @FeatureEnvironment(\.uuid) var uuid

    public init() {}

    public var body: some Feature {
        Update { state, action in
            switch action {
            case .importUsdz(let payload):
                do {
                    let captured = try roomFromUsdz(payload)
                    let item = RoomItem(
                        id: uuid(),
                        name: captured.name,
                        room: captured.room,
                        thresholds: captured.thresholds,
                        windows: captured.windows
                    )
                    state.rooms.append(item)
                    state.selectedID = item.id
                    state.error = nil
                } catch {
                    state.error = error.localizedDescription
                }
            case .splitSelectedButtonTapped:
                guard let selectedID = state.selectedID,
                      let index = state.rooms.firstIndex(where: { $0.id == selectedID })
                else { return }
                do {
                    let atMm = try metresToMm(state.splitAtM)
                    let original = state.rooms[index]
                    let (left, right) = try splitRoom(original.room, axis: state.splitAxis, atMm: atMm)
                    guard let left, let right else {
                        state.error = LayoutError.splitLeavesNoArea.errorDescription
                        return
                    }
                    let first = RoomItem(
                        id: uuid(),
                        name: "\(original.name) A",
                        room: left,
                        thresholds: original.thresholds,
                        windows: original.windows
                    )
                    let second = RoomItem(
                        id: uuid(),
                        name: "\(original.name) B",
                        room: right,
                        thresholds: original.thresholds,
                        windows: original.windows
                    )
                    state.rooms.replaceSubrange(index...index, with: [first, second])
                    state.selectedID = first.id
                    state.error = nil
                } catch {
                    state.error = error.localizedDescription
                }
            }
        }
    }
}
