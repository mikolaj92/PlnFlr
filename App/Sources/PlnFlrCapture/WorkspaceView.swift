import ComposableArchitecture2
import Foundation
import PlnFlrLayout
import SceneKit
import SwiftUI
import UniformTypeIdentifiers

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
                    UtilitiesView(store: projectStore)
                    DrillCheckView(routes: project.utilities)
                        .id(project.projectID)
                    if !project.scans.isEmpty || !project.furniture.isEmpty {
                        ScanSceneView(scans: project.scans, furniture: project.furniture)
                        RoomPlanSourceListView(scans: project.scans)
                        if project.scans.count >= 2 {
                            Text("Skany pozostają osobne. Nakładające się ściany nie są automatycznie usuwane. Wycinanie duplikatów nie jest jeszcze dostępne.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ModelPartsView(store: projectStore)
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
                        HStack {
                            Button("Utwórz wariant podłogi") { store.send(.createFloorVariantButtonTapped(project.id)) }
                                .disabled(project.activeFloorVariant != nil || project.selectedFloorIDs.isEmpty)
                            Button("Policz zakres") { store.send(.planSelectedFloorsButtonTapped(project.id)) }
                                .disabled(project.selectedFloorIDs.isEmpty)
                            if project.activeFloorVariant != nil {
                                Button("Cofnij wariant podłogi") { projectStore.send(.undoLastFloorVariantButtonTapped) }
                            }
                        }
                        Text("Zakres: \(project.selectedFloorIDs.count) powierzchni. \(FloorVariant.sumLabel). Bez optymalizacji odpadów między pokojami.")
                            .font(.caption).foregroundStyle(.secondary)
                        if let floors = project.selectedPlans {
                            Text("Netto \(approximateArea(floors.reduce(0) { $0 + ($1.plan?.bom.areaNetMm2 ?? 0) })) · materiał \(approximateArea(floors.reduce(0) { $0 + ($1.plan?.bom.areaBoughtMm2 ?? 0) }))")
                            Text("Elementy: \(floors.reduce(0) { $0 + ($1.plan?.bom.pieces ?? 0) }). Paczki i materiał osobno dla każdego pokoju.")
                        }
                        ForEach(projectStore.scope(\.floors).filter { project.selectedFloorIDs.contains($0.floorID) }) { floor in
                            FloorView(store: floor,
                                      locked: !store.hasPro && store.freeRoomID != nil && store.freeRoomID != floor.accessID,
                                      editable: project.activeFloorVariant?.floorIDs.contains(floor.floorID) == true) {
                                store.send(.planFloorButtonTapped(project.id, floor.floorID))
                            }
                        }
                        DisclosureGroup("Podział i łączenie powierzchni") {
                            SplitControlsView(store: projectStore,
                                split: { store.send(.splitSelectedButtonTapped) },
                                join: { store.send(.joinSelectedButtonTapped) },
                                undo: { projectStore.send(.undoLastGeometryCorrectionButtonTapped) },
                                planSelection: { store.send(.planSelectedFloorsButtonTapped(project.id)) },
                                undoVariant: { projectStore.send(.undoLastFloorVariantButtonTapped) })
                                .disabled(project.activeFloorVariant != nil)
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

private struct UtilitiesView: View {
    @Bindable var store: StoreOf<Workspace.Project>
    @State private var draft: UtilityRouteDraft?
    @State private var scene: SCNScene?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instalacje").font(.headline)
            if store.utilities.isEmpty {
                Text("Przebieg instalacji nieznany")
            } else {
                if let scene {
                    SceneView(scene: scene, pointOfView: scene.rootNode.childNode(withName: "utilities.camera", recursively: false),
                              options: [.allowsCameraControl, .autoenablesDefaultLighting], preferredFramesPerSecond: 30)
                        .frame(height: 360)
                        .accessibilityLabel("Trasy instalacji 3D. Przeciągnij, aby obrócić widok.")
                }
                ForEach(store.utilities) { route in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.name).font(.headline)
                        Text("Średnica: \(route.diameterMm) mm · Kolor: \(UtilityRoute.colorLabels[route.colorName] ?? route.colorName)")
                        Text("Stan: \(route.state.label) · Źródło: \(route.source.label) · Pewność: \(route.confidence.label)")
                        Button("Edytuj trasę: \(route.name)") { draft = UtilityRouteDraft(route: route) }
                    }
                }
            }
            Text("Mapa nie potwierdza kompletności instalacji ani bezpieczeństwa wiercenia.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Dodaj trasę instalacji") { draft = UtilityRouteDraft() }
        }
        .onChange(of: store.utilities, initial: true) { _, routes in
            scene = HouseScene.scene(walls: [], routes: routes, furniture: [])
        }
        .sheet(item: $draft) { value in
            UtilityRouteEditor(store: store, draft: value)
        }
    }
}

private struct DrillCheckView: View {
    var routes: [UtilityRoute]
    @State private var x = "0"
    @State private var y = "0"
    @State private var z = "0"
    @State private var dx = "0"
    @State private var dy = "1"
    @State private var dz = "0"
    @State private var depth = "100"
    @State private var diameter = "6"
    @State private var submitted = false

    private var answer: DrillAnswer {
        guard let x = Int(x), let y = Int(y), let z = Int(z),
              let dx = Int(dx), let dy = Int(dy), let dz = Int(dz),
              let depth = Int(depth), let diameter = Int(diameter) else { return .invalidQuery }
        return HouseScene.drill(DrillQuery(
            origin: ScenePoint(xMm: x, yMm: y, zMm: z),
            direction: ScenePoint(xMm: dx, yMm: dy, zMm: dz),
            depthMm: depth, diameterMm: diameter), routes: routes)
    }

    var body: some View {
        DisclosureGroup("Sprawdź otwór względem zapisanych instalacji") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Współrzędne w układzie projektu, w całych milimetrach. Kierunek określa wektor, nie punkt końcowy.")
                field("Punkt wejścia X (mm)", text: $x)
                field("Punkt wejścia Y (mm)", text: $y)
                field("Punkt wejścia Z (mm)", text: $z)
                field("Kierunek X", text: $dx)
                field("Kierunek Y", text: $dy)
                field("Kierunek Z", text: $dz)
                field("Głębokość otworu (mm)", text: $depth)
                field("Średnica otworu (mm)", text: $diameter)
                Button("Sprawdź zapisane trasy") { submitted = true }
                if submitted {
                    switch answer {
                    case .unknown:
                        Text("Brak zapisanych tras. Przebieg instalacji jest nieznany.")
                    case .invalidQuery:
                        Text("Wprowadź całkowite współrzędne, niezerowy kierunek oraz dodatnią głębokość i średnicę.")
                    case .incomplete(let hits):
                        Text("Niektóre trasy mają błędną lub niekompletną geometrię. Wynik jest niepełny.")
                        hitList(hits)
                    case .hits(let hits):
                        if hits.isEmpty {
                            Text("Brak przecięć zapisanych tras. Nie oznacza to braku instalacji.")
                        } else {
                            hitList(hits)
                        }
                    }
                }
                Text("Otwór jest skończonym walcem. Trasy uwzględniają własny promień, także przy końcach odcinków. Styczność jest trafieniem. Tolerancja: 0,1 mm.")
                    .font(.caption)
                Text("Dane mogą być niepełne. Żaden wynik nie potwierdza bezpieczeństwa wiercenia. Zapytanie nie jest zapisywane ani eksportowane.")
                    .font(.caption)
            }
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading) {
            Text(title)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(title)
        }
    }

    private func hitList(_ hits: [DrillHit]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(hits, id: \.routeID) { hit in
                VStack(alignment: .leading) {
                    Text(hit.name).font(.headline)
                    Text(hit.confidence == .confirmed && hit.state == .existing
                         ? "Przecięcie potwierdzonej trasy w zapisanej geometrii."
                         : "Możliwe przecięcie trasy niepewnej lub planowanej.")
                    Text("Źródło: \(hit.source.label) · Pewność: \(hit.confidence.label) · Stan: \(hit.state.label)")
                }
            }
        }
    }
}

private struct UtilityRouteEditor: View {
    @Bindable var store: StoreOf<Workspace.Project>
    @State var draft: UtilityRouteDraft
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nazwa trasy", text: $draft.name)
                Picker("Kolor", selection: $draft.colorName) {
                    ForEach(UtilityRoute.colors, id: \.self) { color in
                        Text(UtilityRoute.colorLabels[color] ?? color).tag(color)
                    }
                    if !UtilityRoute.colors.contains(draft.colorName) {
                        Text("Nieobsługiwany: \(draft.colorName)").tag(draft.colorName)
                    }
                }
                TextField("Średnica (mm)", text: $draft.diameter)
                Picker("Stan", selection: $draft.state) {
                    Text("Wybierz stan").tag(Optional<RecordState>.none)
                    ForEach(RecordState.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                }
                Picker("Źródło", selection: $draft.source) {
                    Text("Wybierz źródło").tag(Optional<UtilitySource>.none)
                    ForEach(UtilitySource.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                }
                Picker("Pewność", selection: $draft.confidence) {
                    Text("Wybierz pewność").tag(Optional<UtilityConfidence>.none)
                    ForEach(UtilityConfidence.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                }
                Section("Punkty w kolejności trasy (mm)") {
                    Text("X i Y: położenie na podłodze. Z: wysokość.")
                    ForEach($draft.points) { $point in
                        VStack(alignment: .leading) {
                            Text("Punkt \((draft.points.firstIndex(where: { $0.id == point.id }) ?? 0) + 1)")
                            TextField("X (mm)", text: $point.x)
                            TextField("Y (mm)", text: $point.y)
                            TextField("Z (mm)", text: $point.z)
                            Button("Usuń punkt", role: .destructive) {
                                draft.points.removeAll { $0.id == point.id }
                            }
                        }
                    }
                    Button("Dodaj punkt") { draft.points.append(UtilityRouteDraft.Point()) }
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            }
            .textFieldStyle(.roundedBorder)
            .navigationTitle(draft.routeID == nil ? "Nowa trasa" : "Edycja trasy")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        do {
                            _ = try draft.validatedRoute(id: draft.routeID ?? draft.id)
                            store.send(.saveUtility(draft))
                            if let message = store.utilityError {
                                error = message
                            } else {
                                dismiss()
                            }
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
            }
        }
        .frame(minWidth: 320, minHeight: 480)
    }
}

private struct ScanSceneView: View {
    let scans: [Workspace.Scan.State]
    var selection: [String]? = nil
    var furniture: [FurnitureItem] = []
    var title = "Wspólna mapa skanów 3D"
    var allowsWallAppearance = false
    @State private var scene: SCNScene?
    @State private var errors: [String] = []
    #if os(iOS)
    @State private var wallAppearances: [HouseScene.WallAppearance] = []
    @State private var wallColor = "existing"
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if let scene {
                SceneView(scene: scene, pointOfView: scene.rootNode.childNode(withName: "scans.camera", recursively: false),
                          options: [.allowsCameraControl, .autoenablesDefaultLighting], preferredFramesPerSecond: 30)
                    .frame(height: 360)
                    .accessibilityLabel("Wspólna mapa skanów. Źródła: \(scans.count)")
                    .accessibilityIdentifier("scanScenePreview")
            }
            #if os(iOS)
            if allowsWallAppearance {
                Text(RoomPlanStructureSource.appearanceDisclosure)
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Wygląd ścian", selection: $wallColor) {
                    Text("Stan istniejący").tag("existing")
                    Text("Biały").tag("white")
                    Text("Beżowy").tag("beige")
                    Text("Zielony").tag("green")
                }
                .disabled(wallAppearances.isEmpty)
                .onChange(of: wallColor) { _, color in
                    let colors: [String: UIColor] = [
                        "white": .white,
                        "beige": UIColor(red: 0.85, green: 0.78, blue: 0.65, alpha: 1),
                        "green": UIColor(red: 0.55, green: 0.65, blue: 0.50, alpha: 1)
                    ]
                    for wall in wallAppearances { wall.apply(color: colors[color]) }
                }
                if wallAppearances.isEmpty, let scan = scans.first {
                    Text(RoomPlanStructureSource.wallAppearanceLimitation(scan))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            #endif
            ForEach(Array(errors.enumerated()), id: \.offset) { _, message in
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
            }
            ForEach(furniture) { item in
                if !item.hidden {
                    VStack(alignment: .leading) {
                        Text(item.name).font(.headline)
                        Text("Wymiary: \(item.size.xMm) × \(item.size.yMm) × \(item.size.zMm) mm")
                        Text(item.state == .existing ? "Stan: istniejący" : "Stan: planowany")
                        Text("Pochodzenie: \(item.provenance ?? "niezapisane w modelu")")
                    }
                }
            }
            Text(RoomPlanStructureSource.unverifiedAccuracyDisclosure)
                .font(.caption).foregroundStyle(.secondary)
            Text("Ustawienie zmienia tylko podgląd źródła. Podłogi i obliczenia pozostają bez zmian.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of: scans, initial: true) { _, _ in refreshScene() }
        .onChange(of: selection) { _, _ in refreshScene() }
        .onChange(of: furniture) { _, _ in refreshScene() }
    }

    private func refreshScene() {
        let preview = HouseScene.scans(scans, selection: selection, furniture: furniture)
        scene = preview.scene.rootNode.childNode(withName: "scans.camera", recursively: false) == nil ? nil : preview.scene
        errors = preview.errors
        #if os(iOS)
        wallColor = "existing"
        wallAppearances = []
        if allowsWallAppearance {
            do {
                for scan in scans {
                    wallAppearances += try HouseScene.wallAppearances(scan, in: preview.scene)
                }
            } catch {
                errors.append(error.localizedDescription)
            }
        }
        #endif
    }
}

private struct ModelPartsView: View {
    @Bindable var store: StoreOf<Workspace.Project>
    @State private var scanID: UUID?
    @State private var paths: Set<String> = []
    @State private var name = "Część modelu"
    @State private var elements: [HouseScene.Element] = []
    @State private var rooms: [HouseScene.RoomSelection] = []
    @State private var error: String?
    @State private var preview: ModelPart?

    var body: some View {
        DisclosureGroup("Części modelu 3D") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Źródło", selection: $scanID) {
                    Text("Wybierz źródło").tag(nil as UUID?)
                    ForEach(store.scans) { scan in
                        Text(scan.label).tag(Optional(scan.id))
                    }
                }
                TextField("Nazwa części", text: $name)
                ForEach(rooms) { room in
                    Button("Wybierz pokój RoomPlan: \(room.id)") { paths = Set(room.paths) }
                }
                Text("Zaznaczenie elementów nie tworzy pokoju ani podłogi.")
                    .font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(elements) { element in
                            Toggle(element.name, isOn: Binding(
                                get: { paths.contains(element.id) },
                                set: { selected in
                                    if selected { paths.insert(element.id) } else { paths.remove(element.id) }
                                }
                            ))
                        }
                    }
                }
                .frame(maxHeight: 240)
                HStack {
                    Button("Podgląd zaznaczenia") {
                        if let scanID {
                            preview = ModelPart(id: UUID(), name: name, scanID: scanID, nodePaths: paths.sorted())
                        }
                    }
                    Button("Wydziel część") {
                        if let scanID { store.send(.extractPart(scanID, name, paths.sorted())) }
                    }
                }
                .disabled(scanID == nil)
                if let message = error ?? store.error {
                    Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
                ForEach(store.parts) { part in
                    HStack {
                        Text(part.name)
                        Button("Podgląd") { preview = part }
                        Button("Odłącz") { store.send(.detachPart(part.id)) }
                    }
                }
                if !store.parts.isEmpty {
                    Button("Cofnij ostatnie wydzielenie") { store.send(.undoLastPartButtonTapped) }
                }
            }
        }
        .onChange(of: scanID) { _, _ in loadSource() }
        .onChange(of: store.scans) { _, _ in loadSource() }
        .sheet(item: $preview) { part in
            VStack {
                Text(part.name).font(.headline)
                if let scan = store.scans.first(where: { $0.id == part.scanID }) {
                    ScanSceneView(scans: [scan], selection: part.nodePaths)
                } else {
                    Label("Brak zachowanego źródła 3D.", systemImage: "exclamationmark.triangle")
                }
                Button("Zamknij") { preview = nil }
            }
            .padding()
        }
    }

    private func loadSource() {
        paths = []
        elements = []
        rooms = []
        error = nil
        guard let scan = store.scans.first(where: { $0.id == scanID }) else { return }
        do {
            elements = try HouseScene.elements(scan)
            rooms = try HouseScene.rooms(scan)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct RoomPlanSourceListView: View {
    let scans: [Workspace.Scan.State]
    @State private var selectedScan: Workspace.Scan.State?

    private var listed: [Workspace.Scan.State] { scans }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(listed, id: \.id) { scan in
                sourceCard(scan)
            }
        }
        .accessibilityIdentifier("roomPlan3DSourceList")
        .sheet(item: $selectedScan) { scan in
            VStack {
                if let current = scans.first(where: { $0.id == scan.id }) {
                    ScanSceneView(scans: [current], title: "USDZ · \(current.label)")
                } else {
                    Label("\(scan.label): brak zachowanego źródła 3D.", systemImage: "exclamationmark.triangle")
                }
                Button("Zamknij") { selectedScan = nil }
            }
            .padding()
            #if os(macOS)
            .frame(minWidth: 480, minHeight: 440)
            #endif
        }
    }

    @ViewBuilder
    private func sourceCard(_ scan: Workspace.Scan.State) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title(scan), systemImage: "view.3d")
                .font(.headline)
            if scan.sourceUsdz != nil {
                Text(RoomPlanStructureSource.unverifiedAccuracyDisclosure)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Otwórz podgląd 3D") { selectedScan = scan }
            } else {
                #if os(iOS)
                ScanSceneView(scans: [scan], title: "Źródłowy model 3D", allowsWallAppearance: true)
                #else
                Text(RoomPlanStructureSource.unverifiedAccuracyDisclosure)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(limit(scan))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif
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
        if scan.roomPlanStructure != nil || scan.roomPlanJSON != nil {
            return "Podgląd 3D skanu RoomPlan jest dostępny w aplikacji na iPhone’a lub iPada."
        }
        return "Brak zachowanego źródła 3D."
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
                    Text("Skany z osobnych sesji nie są dopasowywane automatycznie. Ustaw ich położenie ręcznie.")
                        .font(.caption).foregroundStyle(.secondary)
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
    @State private var placementError: String?

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
            Text("Ręczne ustawienie: X \(store.transform.xMm) mm, Y \(store.transform.yMm) mm, Z \(store.transform.zMm) mm, obrót \(store.transform.yawDegrees)°")
                .font(.caption).foregroundStyle(.secondary)
            TextField("X (mm)", text: $xMm)
            TextField("Y (mm)", text: $yMm)
            TextField("Z (mm)", text: $zMm)
            TextField("Obrót (°)", text: $yawDegrees)
            Text("Pochodzenie ustawienia: \(ScanPlacement.Provenance.manualCorrection.label)")
                .font(.caption).foregroundStyle(.secondary)
            Button("Zapisz ręczne ustawienie") {
                guard let x = Int(xMm), let y = Int(yMm), let z = Int(zMm), let yaw = Int(yawDegrees) else {
                    placementError = "Wpisz liczby całkowite: X, Y, Z w milimetrach, obrót w stopniach."
                    return
                }
                placementError = nil
                store.send(.setManualPlacementButtonTapped(ScanTransform(xMm: x, yMm: y, zMm: z, yawDegrees: yaw)))
            }
            if let placementError {
                Label(placementError, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
            }
        }
        .onChange(of: store.transform, initial: true) { _, transform in
            xMm = String(transform.xMm)
            yMm = String(transform.yMm)
            zMm = String(transform.zMm)
            yawDegrees = String(transform.yawDegrees)
            placementError = nil
        }
    }
}

private struct RoomSelectionView: View {
    @Bindable var store: StoreOf<Workspace.Project>
    var body: some View {
        VStack(alignment: .leading) {
            Text("Wybierz zakres").font(.headline)
            HStack {
                Button("Cały dom") { $store.selectedFloorIDs.wrappedValue = store.floors.map(\.id) }
                ForEach(Array(Set(store.floors.compactMap(\.storey).filter { !$0.isEmpty })).sorted(), id: \.self) { storey in
                    Button(storey) {
                        $store.selectedFloorIDs.wrappedValue = store.floors.filter { $0.storey == storey }.map(\.id)
                    }
                }
            }
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
            ForEach(store.floorVariants.filter { $0.before == nil }) { variant in
                Text("Historyczna suma: \(variant.pieces) elementów, netto \(approximateArea(variant.areaNetMm2)). Bez migawki do cofnięcia.")
                    .font(.caption).foregroundStyle(.secondary)
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
    public var editable: Bool
    public var onPlan: () -> Void

    public init(store: StoreOf<Workspace.Floor>, locked: Bool = false, editable: Bool = true, onPlan: @escaping () -> Void) {
        self.store = store
        self.locked = locked
        self.editable = editable
        self.onPlan = onPlan
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Nazwa pokoju", text: $store.name).font(.title2.bold())
            TextField("Kondygnacja (pusta = nieznana)", text: Binding(
                get: { store.storey ?? "" },
                set: { value in
                    let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    $store.storey.wrappedValue = name.isEmpty ? nil : name
                }
            ))
            Text(editable ? "Wariant podłogi" : "Stan obecny — utwórz wariant przed edycją materiału").font(.headline)
            Text("Ilości są szacunkiem zależnym od geometrii i wymiarów. Kolor podglądu nie oznacza produktu ani ceny.")
                .font(.caption).foregroundStyle(.secondary)
            Group {
            Picker("Kolor podglądu", selection: $store.finish) {
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
            }
            .disabled(!editable || locked)
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
                    Text("Netto \(approximateArea(plan.bom.areaNetMm2)) · materiał \(approximateArea(plan.bom.areaBoughtMm2))")
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
