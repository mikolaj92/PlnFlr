import ComposableArchitecture2
import Foundation
import PlnFlrLayout
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import QuickLook
#endif

public struct WorkspaceView: View {
    @Bindable public var store: StoreOf<Workspace>
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<Workspace>) { self.store = store }

    public var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("Projekty")
        } detail: {
            detail
                .navigationTitle(currentProject?.name ?? "PlnFlr")
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    #if os(iOS)
                    Button("Skanuj pomieszczenia", systemImage: "camera.viewfinder") { store.send(.scanRoomButtonTapped) }
                    #endif
                    Button("Nowy projekt", systemImage: "folder.badge.plus") { store.send(.newProjectButtonTapped) }
                    Button("Dodaj pokój", systemImage: "rectangle.badge.plus") { $store.isAddingRoom.wrappedValue = true }
                    Button("Importuj USDZ", systemImage: "square.and.arrow.down") { $store.isImporting.wrappedValue = true }
                } label: {
                    Label("Dodaj", systemImage: "plus")
                }
                .accessibilityIdentifier("addMenu")
                Button(store.hasPro ? "Pro aktywne" : "PlnFlr Pro", systemImage: "sparkles") {
                    $store.isPaywallPresented.wrappedValue = true
                }
                .accessibilityIdentifier("proButton")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let message = store.storageError {
                VStack(alignment: .leading) {
                    Label(message, systemImage: "exclamationmark.triangle")
                    Button("Spróbuj ponownie") {
                        store.send(store.hasLoaded ? .retrySaveButtonTapped : .appStarted)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $store.isCapturingRoom) {
            RoomScannerView(
                onSave: { store.send(.structureCaptureFinished($0)) },
                onCancel: { store.send(.roomCaptureCancelled) },
                onFailure: { store.send(.roomCaptureFailed($0)) }
            )
            .interactiveDismissDisabled()
        }
        #endif
        .sheet(isPresented: $store.isAddingRoom) { ManualRoomView(store: store) }
        .sheet(isPresented: $store.isPaywallPresented) { ProView(store: store) }
        .fileImporter(isPresented: $store.isImporting, allowedContentTypes: [.usdz], onCompletion: importUsdz)
        .task {
            store.send(.appStarted)
            store.send(.storeStarted)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.send(.refreshAccess) }
            if phase == .background { store.send(.retrySaveButtonTapped) }
        }
    }

    private var currentProject: Workspace.Project.State? {
        store.projects.first { $0.projectID == store.selectedProjectID }
    }

    private var currentProjectStore: StoreOf<Workspace.Project>? {
        store.scope(\.projects).first { $0.projectID == store.selectedProjectID }
    }

    @ViewBuilder
    private var sidebar: some View {
        if store.projects.isEmpty {
            WelcomeView(store: store)
        } else {
            List(selection: $store.selectedProjectID) {
                ForEach(store.projects, id: \.projectID) { project in
                    Label(project.name, systemImage: "house")
                        .tag(project.projectID)
                }
            }
            if let project = currentProjectStore {
                ProjectRoomsView(store: project)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let project = currentProject, let projectStore = currentProjectStore {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ProjectHeaderView(store: projectStore)
                    if !project.scans.isEmpty {
                        RoomPlanSourceListView(scans: project.scans)
                    }
                    if project.floors.isEmpty {
                        if !project.scans.isEmpty {
                            Label("Zapisane skany: \(project.scans.count). Skany z aparatu zachowują pełny model RoomPlan; podłogi nie zostały jeszcze wyprowadzone.", systemImage: "checkmark.circle")
                        }
                        WelcomeView(store: store)
                    } else {
                        HouseCanvas(floors: project.floors, selectedID: project.selectedFloorIDs.first)
                            .frame(height: 220)
                            .padding()
                            .background(.quaternary, in: .rect(cornerRadius: 16))
                        RoomSelectionView(store: projectStore)
                        if let message = project.error ?? store.error {
                            Label(message, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                                .accessibilityIdentifier("workspaceError")
                        }
                        if project.selectedFloorIDs.count == 1,
                           let id = project.selectedFloorIDs.first,
                           let floor = projectStore.scope(\.floors).first(where: { $0.floorID == id }) {
                            FloorView(store: floor, locked: !store.hasPro && store.freeRoomID != nil && store.freeRoomID != floor.accessID) {
                                store.send(.planFloorButtonTapped(project.id, id))
                            }
                        }
                        DisclosureGroup("Podział i łączenie powierzchni") {
                            SplitControlsView(store: projectStore,
                                split: { store.send(.splitSelectedButtonTapped) },
                                join: { store.send(.joinSelectedButtonTapped) },
                                undo: { projectStore.send(.undoLastGeometryCorrectionButtonTapped) },
                                planSelection: { store.send(.planSelectedFloorsButtonTapped(project.id)) },
                                undoVariant: { projectStore.send(.undoLastFloorVariantButtonTapped) })
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 960)
                .frame(maxWidth: .infinity)
            }
        } else {
            WelcomeView(store: store)
        }
    }

    private func importUsdz(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 50 * 1024 * 1024 else {
                store.send(.importFailed("Skan przekracza limit 50 MB."))
                return
            }
            store.send(.importUsdz(try Data(contentsOf: url)))
        } catch {
            if (error as NSError).code != NSUserCancelledError {
                store.send(.importFailed("Nie udało się otworzyć skanu: \(error.localizedDescription)"))
            }
        }
    }
}

private struct ProjectHeaderView: View {
    @Bindable var store: StoreOf<Workspace.Project>
    var body: some View {
        TextField("Nazwa projektu", text: $store.name)
            .font(.title.bold())
            .accessibilityIdentifier("projectName")
    }
}

private struct RoomPlanSourceListView: View {
    let scans: [Workspace.Scan.State]
    @State private var previewURL: URL?
    @State private var previewError: String?

    private var listed: [Workspace.Scan.State] {
        scans.filter { $0.roomPlanStructure != nil || $0.sourceUsdz != nil }
    }

    var body: some View {
        #if os(iOS)
        VStack(alignment: .leading, spacing: 16) {
            ForEach(listed, id: \.id) { scan in
                sourceCard(scan)
            }
        }
        .quickLookPreview($previewURL)
        .accessibilityIdentifier("roomPlan3DSourceList")
        #else
        VStack(alignment: .leading, spacing: 16) {
            ForEach(listed, id: \.id) { scan in
                sourceCard(scan, interactive: false)
            }
        }
        .accessibilityIdentifier("roomPlan3DSourceList")
        #endif
    }

    @ViewBuilder
    private func sourceCard(_ scan: Workspace.Scan.State, interactive: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title(scan), systemImage: "view.3d")
                .font(.headline)
            Text(RoomPlanStructureSource.unverifiedAccuracyDisclosure)
                .font(.caption)
                .foregroundStyle(.secondary)
            #if os(iOS)
            if interactive, let source = scan.roomPlanStructure {
                Button("Otwórz podgląd 3D") {
                    do {
                        previewError = nil
                        previewURL = try RoomPlanStructurePreview.exportURL(source)
                    } catch {
                        previewError = "Nie udało się przygotować podglądu: \(error.localizedDescription)"
                    }
                }
            } else {
                Text(limit(scan))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #else
            Text(limit(scan))
                .font(.caption)
                .foregroundStyle(.secondary)
            #endif
            if let previewError {
                Label(previewError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: .rect(cornerRadius: 12))
        .accessibilityIdentifier("roomPlanSource.\(scan.id.uuidString)")
    }

    private func title(_ scan: Workspace.Scan.State) -> String {
        RoomPlanStructureSource.listedSourceTitle(
            label: scan.label,
            roomCount: scan.roomPlanStructure?.rooms.count,
            hasSourceUsdz: scan.sourceUsdz != nil
        ) ?? scan.label
    }

    private func limit(_ scan: Workspace.Scan.State) -> String {
        if scan.roomPlanStructure != nil {
            return "Podgląd 3D skanu RoomPlan jest dostępny w aplikacji na iPhone’a lub iPada."
        }
        return "Zachowano oryginalny plik USDZ. Interaktywny podgląd meshu nie jest jeszcze dostępny na tym urządzeniu."
    }
}

private struct ProjectRoomsView: View {
    @Bindable var store: StoreOf<Workspace.Project>
    var body: some View {
        List {
            Section("Pokoje") {
                ForEach(store.floors, id: \.floorID) { floor in
                    Button {
                        $store.selectedFloorIDs.wrappedValue = [floor.id]
                    } label: {
                        Label(floor.name, systemImage: store.selectedFloorIDs.contains(floor.id) ? "checkmark.circle.fill" : "circle")
                    }
                    .buttonStyle(.plain)
                }
            }
            if !store.scans.isEmpty {
                Section("Skany źródłowe") {
                    ForEach(store.scope(\.scans)) { scan in ScanRowView(store: scan) }
                    if store.scanPlacements.contains(where: { !store.undoneScanPlacementIDs.contains($0.id) }) {
                        Button("Cofnij ostatnie ustawienie skanu") {
                            store.send(.undoLastScanPlacementButtonTapped)
                        }
                    }
                }
            }
        }
    }
}

private struct ScanRowView: View {
    @Bindable var store: StoreOf<Workspace.Scan>
    @State private var xMm = "0"
    @State private var yMm = "0"
    @State private var zMm = "0"
    @State private var yawDegrees = "0"

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Nazwa skanu", text: $store.label)
            if let source = store.roomPlanStructure {
                Text("RoomPlan: \(source.rooms.count) pokoi we wspólnej sesji")
                    .font(.caption).foregroundStyle(.secondary)
            } else if store.sourceUsdz != nil {
                Text("Oryginalny USDZ zachowany · powierzchnie: \(store.rooms.count)")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(store.roomPlanJSON == nil ? "Powierzchnie: \(store.rooms.count)" : "Pełny skan RoomPlan zapisany")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Ustawienie: X \(store.transform.xMm) mm, Y \(store.transform.yMm) mm, Z \(store.transform.zMm) mm, obrót \(store.transform.yawDegrees)°")
                .font(.caption).foregroundStyle(.secondary)
            TextField("X (mm)", text: $xMm)
            TextField("Y (mm)", text: $yMm)
            TextField("Z (mm)", text: $zMm)
            TextField("Obrót (°)", text: $yawDegrees)
            Button("Ustaw skan") {
                guard let x = Int(xMm), let y = Int(yMm), let z = Int(zMm), let yaw = Int(yawDegrees) else { return }
                store.send(.setManualPlacementButtonTapped(ScanTransform(xMm: x, yMm: y, zMm: z, yawDegrees: yaw)))
            }
        }
    }
}

private struct RoomSelectionView: View {
    @Bindable var store: StoreOf<Workspace.Project>
    var body: some View {
        VStack(alignment: .leading) {
            Text("Wybierz pokój").font(.headline)
            ScrollView(.horizontal) {
                HStack {
                    ForEach(store.floors, id: \.floorID) { floor in
                        Button(floor.name) { $store.selectedFloorIDs.wrappedValue = [floor.id] }
                            .buttonStyle(.bordered)
                            .tint(store.selectedFloorIDs.contains(floor.id) ? .accentColor : .secondary)
                    }
                }
            }
        }
    }
}

private struct SplitControlsView: View {
    @Bindable var store: StoreOf<Workspace.Project>
    var split: () -> Void
    var join: () -> Void
    var undo: () -> Void
    var planSelection: () -> Void
    var undoVariant: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Podział jest techniczny — obie części zachowują dostęp pokoju źródłowego. Aby połączyć, zaznacz dokładnie dwie powierzchnie.")
                .font(.caption).foregroundStyle(.secondary)
            if let correction = store.geometryCorrections.last(where: {
                !store.undoneGeometryCorrectionIDs.contains($0.id)
            }) {
                Button("Cofnij ostatnią korektę geometrii") {
                    undo()
                }
                Text("\(correction.before.count) → \(correction.after.count) powierzchni · cofnięcie zachowa poprzednią geometrię.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(store.floors, id: \.floorID) { floor in
                Toggle(floor.name, isOn: $store.selectedFloorIDs[contains: floor.id])
            }
            TextField("Pozycja cięcia od początku mapy (m)", text: $store.splitAtM)
                .textFieldStyle(.roundedBorder)
            Picker("Oś cięcia", selection: $store.splitAxis) {
                Text("X").tag(SplitAxis.x)
                Text("Y").tag(SplitAxis.y)
            }.pickerStyle(.segmented)
            HStack {
                Button("Podziel", action: split).disabled(store.selectedFloorIDs.count != 1)
                Button("Połącz", action: join).disabled(store.selectedFloorIDs.count != 2)
                Button("Policz zaznaczone", action: planSelection).disabled(store.selectedFloorIDs.isEmpty)
            }.buttonStyle(.bordered)
            if let variant = store.floorVariants.last(where: { !store.undoneFloorVariantIDs.contains($0.id) }) {
                Text("\(FloorVariant.sumLabel): \(variant.pieces) elementów, netto \(variant.areaNetMm2) mm²")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Cofnij wariant podłogi") { undoVariant() }
            }
        }.padding(.top)
    }
}

extension Array where Element == UUID {
    subscript(contains id: UUID) -> Bool {
        get { contains(id) }
        set {
            if newValue { if !contains(id) { append(id) } }
            else { removeAll { $0 == id } }
        }
    }
}

public struct FloorView: View {
    @Bindable public var store: StoreOf<Workspace.Floor>
    public var locked: Bool
    public var onPlan: () -> Void

    public init(store: StoreOf<Workspace.Floor>, locked: Bool = false, onPlan: @escaping () -> Void) {
        self.store = store
        self.locked = locked
        self.onPlan = onPlan
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Nazwa pokoju", text: $store.name).font(.title2.bold())
            Text("Ustaw materiał").font(.headline)
            Picker("Wykończenie", selection: $store.finish) {
                Text("Dąb").tag(FloorFinish.oak)
                Text("Orzech").tag(FloorFinish.walnut)
            }.pickerStyle(.segmented)
            Picker("Materiał", selection: $store.material) {
                Text("Deski / panele").tag(FloorMaterial.plank)
                Text("Płytki").tag(FloorMaterial.tile)
            }.pickerStyle(.segmented)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                field("Długość (m)", text: $store.plankLengthM)
                field("Szerokość (m)", text: $store.plankWidthM)
                field("Dylatacja (mm)", text: $store.expansionMm)
                field("Sztuk w paczce", text: $store.packSize)
                if store.material == .tile { field("Fuga (mm)", text: $store.groutMm) }
            }
            Button(locked ? "Odblokuj kolejne pokoje" : "Ułóż podłogę", systemImage: locked ? "lock" : "square.grid.3x3", action: onPlan)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("planFloor")
            if let message = store.error {
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
            }
            if let plan = store.plan {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Plan ułożenia").font(.title2.bold())
                    Text("Elementy: \(plan.bom.pieces) · sztuki materiału: \(plan.bom.fullBoards) · paczki: \(plan.bom.packs.map(String.init) ?? "—")")
                        .accessibilityIdentifier("planSummary")
                    Text("Odpad: \(plan.bom.wastePct)%")
                    Text(plan.rationalePl).foregroundStyle(.secondary)
                    Picker("Podgląd", selection: $store.isShowing3DPreview) {
                        Text("2D").tag(false)
                        Text("3D").tag(true)
                    }.pickerStyle(.segmented)
                    if store.isShowing3DPreview {
                        Floor3DPreview(plan: plan, finish: store.finish, material: store.material)
                            .frame(height: 320)
                            .accessibilityIdentifier("floor3DPreview")
                    } else {
                        FloorCanvas(plan: plan, finish: store.finish, material: store.material)
                            .frame(height: 320)
                            .accessibilityIdentifier("floorPreview")
                    }
                    ForEach(Array(plan.warnings.enumerated()), id: \.offset) { _, warning in
                        Label(warning.messagePl, systemImage: "exclamationmark.triangle")
                    }
                    DisclosureGroup("Kolejność układania") {
                        ForEach(Array(plan.rowsInstructionPl.enumerated()), id: \.offset) { _, line in
                            Text(line).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        GridRow {
            Text(label)
            TextField(label, text: text).textFieldStyle(.roundedBorder)
                .accessibilityLabel(label)
                .frame(maxWidth: 200)
        }
    }
}

struct HouseCanvas: View {
    var floors: [Workspace.Floor.State]
    var selectedID: UUID?

    var body: some View {
        Canvas { context, size in
            let vertices = floors.flatMap { $0.room.outer.vertices }
            let minX = vertices.map(\.xMm).min() ?? 0
            let minY = vertices.map(\.yMm).min() ?? 0
            let width = max(CGFloat((vertices.map(\.xMm).max() ?? 1) - minX), 1)
            let height = max(CGFloat((vertices.map(\.yMm).max() ?? 1) - minY), 1)
            let scale = min(size.width / width, size.height / height)
            let dx = (size.width - width * scale) / 2
            let dy = (size.height - height * scale) / 2
            func point(_ vertex: Vertex) -> CGPoint {
                CGPoint(x: dx + CGFloat(vertex.xMm - minX) * scale,
                        y: size.height - dy - CGFloat(vertex.yMm - minY) * scale)
            }
            for floor in floors {
                let selected = floor.floorID == selectedID
                var shape = path(floor.room.outer.vertices, point)
                for hole in floor.room.holes { shape.addPath(path(hole.vertices, point)) }
                context.fill(shape, with: .color(selected ? .orange.opacity(0.35) : .secondary.opacity(0.15)), style: FillStyle(eoFill: true))
                context.stroke(shape, with: .color(selected ? .orange : .primary.opacity(0.5)), lineWidth: selected ? 2 : 1)
            }
        }
        .accessibilityLabel("Mapa projektu. Powierzchnie: \(floors.count)")
    }

    private func path(_ vertices: [Vertex], _ point: (Vertex) -> CGPoint) -> Path {
        var path = Path()
        guard let first = vertices.first else { return path }
        path.move(to: point(first))
        for vertex in vertices.dropFirst() { path.addLine(to: point(vertex)) }
        path.closeSubpath()
        return path
    }
}
