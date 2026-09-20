import ComposableArchitecture2
import Foundation
import PlnFlrLayout

@Feature
public struct Workspace {
    @Feature
    public struct Scan {
        public struct State: Equatable, Identifiable, Sendable {
            public var id: UUID { scanID }
            public var label: String
            public var rooms: [CapturedRoom]
            public var scanID: UUID

            public init(id: UUID, label: String, rooms: [CapturedRoom]) {
                self.label = label
                self.rooms = rooms
                self.scanID = id
            }
        }

        public init() {}
    }

    @Feature
    public struct Floor {
        public struct State: Equatable, Identifiable, Sendable {
            public var error: String?
            public var expansionMm: String
            public var floorID: UUID
            public var id: UUID { floorID }
            public var name: String
            public var plan: LayoutPlan?
            public var plankLengthM: String
            public var plankWidthM: String
            public var room: Room
            public var thresholds: [Threshold]
            public var windows: [Opening]

            public init(
                id: UUID,
                name: String,
                room: Room,
                thresholds: [Threshold] = [],
                windows: [Opening] = [],
                expansionMm: String = "10",
                plankLengthM: String = "1.383",
                plankWidthM: String = "0.156",
                plan: LayoutPlan? = nil,
                error: String? = nil
            ) {
                self.error = error
                self.expansionMm = expansionMm
                self.floorID = id
                self.name = name
                self.plan = plan
                self.plankLengthM = plankLengthM
                self.plankWidthM = plankWidthM
                self.room = room
                self.thresholds = thresholds
                self.windows = windows
            }
        }

        public enum Action {
            case layButtonTapped
        }

        public init() {}

        public var body: some Feature {
            Update { state, action in
                switch action {
                case .layButtonTapped:
                    do {
                        state.error = nil
                        state.plan = try layoutFloor(
                            state.room,
                            zones: [
                                Zone(
                                    kind: .plank,
                                    plank: PlankSpec(
                                        lengthMm: try metresToMm(state.plankLengthM),
                                        widthMm: try metresToMm(state.plankWidthM),
                                        boardsPerPack: 8
                                    )
                                ),
                            ],
                            rules: LayoutRules(expansionMm: Int(state.expansionMm) ?? 10),
                            windows: state.windows
                        )
                    } catch {
                        state.error = error.localizedDescription
                        state.plan = nil
                    }
                }
            }
        }
    }

    @Feature
    public struct Project {
        public struct State: Equatable, Identifiable, Sendable {
            public var error: String?
            public var floors: [Floor.State]
            public var id: UUID { projectID }
            public var name: String
            public var projectID: UUID
            public var scans: [Scan.State]
            public var selectedFloorIDs: [UUID]
            public var splitAtM: String
            public var splitAxis: SplitAxis

            public init(
                id: UUID,
                name: String,
                scans: [Scan.State] = [],
                floors: [Floor.State] = [],
                selectedFloorIDs: [UUID] = [],
                splitAtM: String = "1.500",
                splitAxis: SplitAxis = .x,
                error: String? = nil
            ) {
                self.error = error
                self.floors = floors
                self.name = name
                self.projectID = id
                self.scans = scans
                self.selectedFloorIDs = selectedFloorIDs
                self.splitAtM = splitAtM
                self.splitAxis = splitAxis
            }
        }

        public enum Action {
            case floors(Floor.State.ID, Floor.Action)
            case floorsSelected([UUID])
            case scanLabelChanged(UUID, String)
            case splitAtChanged(String)
            case splitAxisChanged(SplitAxis)
        }

        public init() {}

        public var body: some Feature {
            Update { state, action in
                switch action {
                case .floors:
                    break
                case .floorsSelected(let ids):
                    state.selectedFloorIDs = ids
                case .scanLabelChanged(let id, let label):
                    if let index = state.scans.firstIndex(where: { $0.scanID == id }) {
                        state.scans[index].label = label
                    }
                case .splitAtChanged(let value):
                    state.splitAtM = value
                case .splitAxisChanged(let axis):
                    state.splitAxis = axis
                }
            }
            .forEach(\.floors) {
                Floor()
            }
        }
    }

    public struct State {
        public var error: String?
        public var isImporting: Bool
        public var projects: [Project.State]
        public var selectedProjectID: UUID?

        public init(
            error: String? = nil,
            isImporting: Bool = false,
            projects: [Project.State] = [],
            selectedProjectID: UUID? = nil
        ) {
            self.error = error
            self.isImporting = isImporting
            self.projects = projects
            self.selectedProjectID = selectedProjectID
        }
    }

    public enum Action {
        case importUsdz(Data)
        case joinSelectedButtonTapped
        case newProjectButtonTapped
        case projects(Project.State.ID, Project.Action)
        case splitSelectedButtonTapped
    }

    @FeatureEnvironment(\.uuid) var uuid

    public init() {}

    public var body: some Feature {
        Update { state, action in
            switch action {
            case .newProjectButtonTapped:
                let project = Project.State(
                    id: uuid(),
                    name: "Projekt \(state.projects.count + 1)"
                )
                state.projects.append(project)
                state.selectedProjectID = project.projectID
                state.error = nil
            case .importUsdz(let payload):
                do {
                    if state.selectedProjectIndex == nil {
                        let project = Project.State(
                            id: uuid(),
                            name: "Projekt \(state.projects.count + 1)"
                        )
                        state.projects.append(project)
                        state.selectedProjectID = project.projectID
                    }
                    guard let index = state.selectedProjectIndex else { return }
                    let captured = try roomFromUsdz(payload)
                    let scan = Scan.State(
                        id: uuid(),
                        label: "Skan \(state.projects[index].scans.count + 1)",
                        rooms: captured.rooms
                    )
                    state.projects[index].scans.append(scan)
                    var floorIDs: [UUID] = []
                    for capturedRoom in captured.rooms {
                        let floor = Floor.State(
                            id: uuid(),
                            name: capturedRoom.name,
                            room: capturedRoom.room,
                            thresholds: capturedRoom.thresholds,
                            windows: capturedRoom.windows
                        )
                        floorIDs.append(floor.floorID)
                        state.projects[index].floors.append(floor)
                    }
                    if let first = floorIDs.first {
                        state.projects[index].selectedFloorIDs = [first]
                    }
                    state.projects[index].error = nil
                    state.error = nil
                } catch {
                    state.error = error.localizedDescription
                }
            case .splitSelectedButtonTapped:
                guard let index = state.selectedProjectIndex else { return }
                let selectedIDs = state.projects[index].selectedFloorIDs
                guard selectedIDs.count == 1,
                      let floorIndex = state.projects[index].floors.firstIndex(where: { $0.floorID == selectedIDs[0] })
                else { return }
                do {
                    let original = state.projects[index].floors[floorIndex]
                    let atMm = try metresToMm(state.projects[index].splitAtM)
                    let (left, right) = try splitRoom(
                        original.room,
                        axis: state.projects[index].splitAxis,
                        atMm: atMm
                    )
                    guard let left, let right else {
                        state.projects[index].error = LayoutError.splitLeavesNoArea.errorDescription
                        return
                    }
                    let first = Floor.State(
                        id: uuid(),
                        name: "\(original.name) A",
                        room: left,
                        thresholds: original.thresholds,
                        windows: original.windows
                    )
                    let second = Floor.State(
                        id: uuid(),
                        name: "\(original.name) B",
                        room: right,
                        thresholds: original.thresholds,
                        windows: original.windows
                    )
                    state.projects[index].floors.replaceSubrange(floorIndex...floorIndex, with: [first, second])
                    state.projects[index].selectedFloorIDs = [first.floorID]
                    state.projects[index].error = nil
                } catch {
                    state.projects[index].error = error.localizedDescription
                }
            case .joinSelectedButtonTapped:
                guard let index = state.selectedProjectIndex else { return }
                let selectedIDs = state.projects[index].selectedFloorIDs
                let selected = state.projects[index].floors.filter { selectedIDs.contains($0.floorID) }
                guard selected.count == 2 else { return }
                do {
                    let joined = try joinRooms(selected[0].room, selected[1].room)
                    let item = Floor.State(
                        id: uuid(),
                        name: selected[0].name,
                        room: joined,
                        thresholds: selected[0].thresholds + selected[1].thresholds,
                        windows: selected[0].windows + selected[1].windows
                    )
                    state.projects[index].floors.removeAll { selectedIDs.contains($0.floorID) }
                    state.projects[index].floors.append(item)
                    state.projects[index].selectedFloorIDs = [item.floorID]
                    state.projects[index].error = nil
                } catch {
                    state.projects[index].error = error.localizedDescription
                }
            case .projects:
                break
            }
        }
        .forEach(\.projects) {
            Project()
        }
    }
}

extension Workspace.State {
    var selectedProjectIndex: Int? {
        guard let selectedProjectID else { return nil }
        return projects.firstIndex(where: { $0.projectID == selectedProjectID })
    }
}
