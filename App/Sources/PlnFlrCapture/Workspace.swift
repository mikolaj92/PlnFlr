import ComposableArchitecture2
import Foundation
import PlnFlrLayout

@Feature
public struct Workspace {
    public static let loadFailureMessage = "Nie udało się odczytać projektów. Plik pozostaje bez zmian. Spróbuj ponownie lub odzyskaj go z kopii zapasowej."
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
            public var material = FloorMaterial.plank
            public var packSize = "8"
            public var groutMm = "3"
            public var accessID: UUID
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
                error: String? = nil,
                accessID: UUID? = nil
            ) {
                self.accessID = accessID ?? id
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

        public init() {}

        public var body: some Feature {
            Update { _, _ in }
                .onChange(of: WorkspaceArchive.FloorRecord(store.state)) { state in
                    state.plan = nil
                    state.error = nil
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
            case scans(Scan.State.ID, Scan.Action)
            case floors(Floor.State.ID, Floor.Action)
        }

        public init() {}

        public var body: some Feature {
            Update { _, _ in }
            .forEach(\.floors) {
                Floor()
            }
            .forEach(\.scans) {
                Scan()
            }
        }
    }

    public struct State {
        public var isPurchasing = false
        public var purchaseMessage: String?
        public var proProduct: ProProduct?
        public var freeRoomID: UUID?
        public var hasPro = false
        public var isPaywallPresented = false
        public var isAddingRoom = false
        public var manualName = "Pokój"
        public var manualWidthM = "4"
        public var manualHeightM = "3"
        public var manualRoomError: String?
        public var hasLoaded = false
        public var storageError: String?
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
        case buyProButtonTapped
        case purchaseFinished(PurchaseOutcome)
        case purchaseFailed(String)
        case restorePurchasesButtonTapped
        case restoreFinished(Bool)
        case storeStarted
        case refreshAccess
        case reloadProductButtonTapped
        case storeProductLoaded(ProProduct?)
        case addRoomButtonTapped
        case appStarted
        case importFailed(String)
        case planFloorButtonTapped(UUID, UUID)
        case proAccessChanged(Bool)
        case retrySaveButtonTapped
        case importUsdz(Data)
        case joinSelectedButtonTapped
        case newProjectButtonTapped
        case projects(Project.State.ID, Project.Action)
        case splitSelectedButtonTapped
    }

    @FeatureEnvironment(\.uuid) var uuid
    @FeatureEnvironment(\.workspaceFiles) var files
    @FeatureEnvironment(\.purchases) var purchases
    @FeatureState var isStoreStarted = false

    public init() {}

    public var body: some Feature {
        Update { state, action in
            if state.storageError != nil && !state.hasLoaded {
                switch action {
                case .addRoomButtonTapped, .importUsdz, .newProjectButtonTapped,
                     .joinSelectedButtonTapped, .splitSelectedButtonTapped,
                     .planFloorButtonTapped, .projects:
                    return
                default: break
                }
            }
            switch action {
            case .refreshAccess:
                let client = purchases
                store.addTask { try store.send(.proAccessChanged(await client.currentAccess())) }
            case .reloadProductButtonTapped:
                let client = purchases
                store.addTask {
                    do { try store.send(.storeProductLoaded(try await client.product())) }
                    catch { try store.send(.purchaseFailed(error.localizedDescription)) }
                }
            case .storeStarted:
                guard !isStoreStarted else { return }
                isStoreStarted = true
                let client = purchases
                let updates = client.updates()
                store.addTask {
                    for await hasPro in updates { try store.send(.proAccessChanged(hasPro)) }
                }
                store.addTask {
                    try store.send(.proAccessChanged(await client.currentAccess()))
                    do { try store.send(.storeProductLoaded(try await client.product())) }
                    catch { try store.send(.purchaseFailed(error.localizedDescription)) }
                }
            case .storeProductLoaded(let product):
                state.proProduct = product
            case .buyProButtonTapped:
                guard !state.isPurchasing else { return }
                state.isPurchasing = true
                state.purchaseMessage = nil
                let client = purchases
                store.addTask {
                    do { try store.send(.purchaseFinished(try await client.purchase())) }
                    catch { try store.send(.purchaseFailed(error.localizedDescription)) }
                }
            case .restorePurchasesButtonTapped:
                guard !state.isPurchasing else { return }
                state.isPurchasing = true
                state.purchaseMessage = nil
                let client = purchases
                store.addTask {
                    do { try store.send(.restoreFinished(try await client.restore())) }
                    catch { try store.send(.purchaseFailed(error.localizedDescription)) }
                }
            case .purchaseFinished(let outcome):
                state.isPurchasing = false
                switch outcome {
                case .purchased:
                    state.hasPro = true
                    state.isPaywallPresented = false
                case .pending:
                    state.purchaseMessage = "Zakup oczekuje na zatwierdzenie przez Apple."
                case .cancelled: break
                }
            case .purchaseFailed(let message):
                state.isPurchasing = false
                state.purchaseMessage = message
            case .restoreFinished(let hasPro):
                state.isPurchasing = false
                state.applyProAccess(hasPro)
                state.purchaseMessage = hasPro ? "Przywrócono PlnFlr Pro." : "Na tym koncie Apple nie znaleziono zakupu PlnFlr Pro."
            case .appStarted:
                guard !state.hasLoaded else { return }
                do {
                    let restored = try files.load().state
                    state.projects = restored.projects
                    state.selectedProjectID = restored.selectedProjectID
                    state.freeRoomID = restored.freeRoomID
                    state.storageError = nil
                    state.hasLoaded = true
                } catch {
                    state.storageError = Self.loadFailureMessage
                }
            case .retrySaveButtonTapped:
                guard state.hasLoaded else { return }
                save(&state)
            case .planFloorButtonTapped(let projectID, let floorID):
                guard let p = state.projects.firstIndex(where: { $0.id == projectID }),
                      let f = state.projects[p].floors.firstIndex(where: { $0.id == floorID }) else { return }
                let floor = state.projects[p].floors[f]
                guard state.hasPro || state.freeRoomID == nil || state.freeRoomID == floor.accessID else {
                    state.isPaywallPresented = true
                    return
                }
                do {
                    let plan = try floor.makePlan()
                    state.projects[p].floors[f].plan = plan
                    state.projects[p].floors[f].error = nil
                    if !state.hasPro && state.freeRoomID == nil { state.freeRoomID = floor.accessID }
                } catch {
                    state.projects[p].floors[f].plan = nil
                    state.projects[p].floors[f].error = error.localizedDescription
                }
            case .proAccessChanged(let hasPro):
                state.applyProAccess(hasPro)
            case .importFailed(let message):
                state.error = message
            case .addRoomButtonTapped:
                do {
                    let width = try metresToMm(state.manualWidthM)
                    let height = try metresToMm(state.manualHeightM)
                    guard (100...100_000).contains(width), (100...100_000).contains(height) else {
                        throw ManualRoomError.invalidDimensions
                    }
                    let room = try rectangle(widthMm: width, heightMm: height)
                    if state.selectedProjectIndex == nil {
                        let project = Project.State(id: uuid(), name: "Projekt \(state.projects.count + 1)")
                        state.projects.append(project)
                        state.selectedProjectID = project.id
                    }
                    guard let index = state.selectedProjectIndex else { return }
                    let name = state.manualName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let floor = Floor.State(id: uuid(), name: name.isEmpty ? "Pokój" : name, room: room)
                    state.projects[index].floors.append(floor)
                    state.projects[index].selectedFloorIDs = [floor.id]
                    state.manualRoomError = nil
                    state.isAddingRoom = false
                    state.error = nil
                } catch {
                    state.manualRoomError = "Wymiary pokoju muszą wynosić od 0,1 do 100 m."
                }
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
                    let captured = try roomFromUsdz(payload)
                    if state.selectedProjectIndex == nil {
                        let project = Project.State(
                            id: uuid(),
                            name: "Projekt \(state.projects.count + 1)"
                        )
                        state.projects.append(project)
                        state.selectedProjectID = project.projectID
                    }
                    guard let index = state.selectedProjectIndex else { return }
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
                    var first = Floor.State(
                        id: uuid(),
                        name: "\(original.name) A",
                        room: left,
                        thresholds: original.thresholds,
                        windows: original.windows,
                        expansionMm: original.expansionMm,
                        plankLengthM: original.plankLengthM,
                        plankWidthM: original.plankWidthM,
                        accessID: original.accessID
                    )
                    var second = Floor.State(
                        id: uuid(),
                        name: "\(original.name) B",
                        room: right,
                        thresholds: original.thresholds,
                        windows: original.windows,
                        expansionMm: original.expansionMm,
                        plankLengthM: original.plankLengthM,
                        plankWidthM: original.plankWidthM,
                        accessID: original.accessID
                    )
                    first.copyMaterial(from: original)
                    second.copyMaterial(from: original)
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
                    var item = Floor.State(
                        id: uuid(),
                        name: selected[0].name,
                        room: joined,
                        thresholds: selected[0].thresholds + selected[1].thresholds,
                        windows: selected[0].windows + selected[1].windows,
                        expansionMm: selected[0].expansionMm,
                        plankLengthM: selected[0].plankLengthM,
                        plankWidthM: selected[0].plankWidthM,
                        accessID: selected[0].accessID == selected[1].accessID ? selected[0].accessID : nil
                    )
                    item.copyMaterial(from: selected[0])
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
        .onChange(of: WorkspaceArchive(store.state)) { state in
            guard state.hasLoaded else { return }
            save(&state)
        }
    }

    private func save(_ state: inout State) {
        do {
            try files.save(WorkspaceArchive(state))
            state.storageError = nil
        } catch {
            state.storageError = "Nie udało się zapisać projektów: \(error.localizedDescription)"
        }
    }
}

extension Workspace.State {
    mutating func applyProAccess(_ value: Bool) {
        hasPro = value
        if value { isPaywallPresented = false }
        if !value {
            for p in projects.indices {
                for f in projects[p].floors.indices where projects[p].floors[f].accessID != freeRoomID {
                    projects[p].floors[f].plan = nil
                }
            }
        }
    }

    var selectedProjectIndex: Int? {
        guard let selectedProjectID else { return nil }
        return projects.firstIndex(where: { $0.projectID == selectedProjectID })
    }
}
