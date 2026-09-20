import ComposableArchitecture2
import PlnFlrLayout
import SwiftUI
import UniformTypeIdentifiers

public struct WorkspaceView: View {
    @Bindable public var store: StoreOf<Workspace>

    public init(store: StoreOf<Workspace>) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Picker("Projekt", selection: $store.selectedProjectID) {
                    ForEach(store.projects, id: \.projectID) { project in
                        Text(project.name).tag(Optional(project.projectID))
                    }
                }
                .labelsHidden()
                .frame(minWidth: 160)
            }
            ToolbarItem {
                Button("Nowy projekt") { store.send(.newProjectButtonTapped) }
            }
            ToolbarItem {
                Button("Importuj USDZ") { $store.isImporting.wrappedValue = true }
            }
        }
        .fileImporter(
            isPresented: $store.isImporting,
            allowedContentTypes: [.usdz]
        ) { result in
            importUsdz(result)
        }
        .navigationTitle(currentProject?.name ?? "PlnFlr")
    }

    private var currentProject: Workspace.Project.State? {
        store.projects.first { $0.projectID == store.selectedProjectID }
    }

    @ViewBuilder
    private var sidebar: some View {
        if let project = currentProject {
            List(selection: floorsSelection) {
                if !project.scans.isEmpty {
                    Section("Skany") {
                        ForEach(project.scans, id: \.scanID) { scan in
                            VStack(alignment: .leading) {
                                TextField(
                                    "Etykieta",
                                    text: Binding(
                                        get: { scan.label },
                                        set: { store.send(.projects(project.projectID, .scanLabelChanged(scan.scanID, $0))) }
                                    )
                                )
                                Text("\(scan.rooms.count) \(scan.rooms.count == 1 ? "podłoga" : "podłogi")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Pokoje") {
                    ForEach(project.floors, id: \.floorID) { floor in
                        Text(floor.name).tag(floor.floorID)
                    }
                }
            }
        } else {
            ContentUnavailableView {
                Label("Brak projektu", systemImage: "house")
            } description: {
                Text("Nowy projekt albo import USDZ.")
            } actions: {
                Button("Nowy projekt") { store.send(.newProjectButtonTapped) }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let project = currentProject {
            VStack(alignment: .leading, spacing: 12) {
                HouseCanvas(floors: project.floors, selectedID: project.selectedFloorIDs.first)
                    .frame(minHeight: 280)
                HStack {
                    TextField(
                        "Cięcie m",
                        text: Binding(
                            get: { project.splitAtM },
                            set: { store.send(.projects(project.projectID, .splitAtChanged($0))) }
                        )
                    )
                    .frame(width: 90)
                    Picker(
                        "Oś",
                        selection: Binding(
                            get: { project.splitAxis },
                            set: { store.send(.projects(project.projectID, .splitAxisChanged($0))) }
                        )
                    ) {
                        Text("X").tag(SplitAxis.x)
                        Text("Y").tag(SplitAxis.y)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                    Button("Podziel") { store.send(.splitSelectedButtonTapped) }
                        .disabled(project.selectedFloorIDs.count != 1)
                    Button("Połącz") { store.send(.joinSelectedButtonTapped) }
                        .disabled(project.selectedFloorIDs.count != 2)
                }
                if let message = project.error ?? store.error {
                    Text(message)
                }
                if project.selectedFloorIDs.count == 1,
                   let selectedID = project.selectedFloorIDs.first,
                   let projectStore = store.scope(\.projects).first(where: { $0.projectID == project.projectID }),
                   let floorStore = projectStore.scope(\.floors).first(where: { $0.floorID == selectedID })
                {
                    FloorView(store: floorStore)
                }
            }
            .padding()
        }
    }

    private var floorsSelection: Binding<Set<UUID>> {
        Binding(
            get: { Set(currentProject?.selectedFloorIDs ?? []) },
            set: { ids in
                guard let projectID = store.selectedProjectID else { return }
                store.send(.projects(projectID, .floorsSelected(Array(ids))))
            }
        )
    }

    private func importUsdz(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        if let data = try? Data(contentsOf: url) {
            store.send(.importUsdz(data))
        }
    }
}

public struct FloorView: View {
    @Bindable public var store: StoreOf<Workspace.Floor>

    public init(store: StoreOf<Workspace.Floor>) {
        self.store = store
    }

    public var body: some View {
        Form {
            Section("Deska") {
                TextField("Długość m", text: $store.plankLengthM)
                TextField("Szerokość m", text: $store.plankWidthM)
                TextField("Dylatacja mm", text: $store.expansionMm)
            }
            Button("Ułóż") { store.send(.layButtonTapped) }
            if let message = store.error {
                Text(message)
            }
            if let plan = store.plan {
                Text("Sztuki \(plan.bom.pieces) · deski \(plan.bom.fullBoards) · paczki \(plan.bom.packs.map(String.init) ?? "—")")
                Text(plan.rationalePl)
                FloorCanvas(plan: plan)
                    .frame(minHeight: 280)
            }
        }
    }
}

struct HouseCanvas: View {
    var floors: [Workspace.Floor.State]
    var selectedID: UUID?

    var body: some View {
        Canvas { context, size in
            let bounds = houseBounds(floors)
            let width = max(CGFloat(bounds.maxX - bounds.minX), 1)
            let height = max(CGFloat(bounds.maxY - bounds.minY), 1)
            let scale = min(size.width / width, size.height / height)
            func point(_ v: Vertex) -> CGPoint {
                CGPoint(
                    x: CGFloat(v.xMm - bounds.minX) * scale,
                    y: size.height - CGFloat(v.yMm - bounds.minY) * scale
                )
            }
            for floor in floors {
                let selected = floor.floorID == selectedID
                context.fill(
                    path(floor.room.outer.vertices, point),
                    with: .color(selected ? Color.orange.opacity(0.35) : Color.secondary.opacity(0.15))
                )
                context.stroke(
                    path(floor.room.outer.vertices, point),
                    with: .color(selected ? .orange : .primary.opacity(0.5)),
                    lineWidth: selected ? 2 : 1
                )
                for hole in floor.room.holes {
                    context.fill(path(hole.vertices, point), with: .color(.white))
                    context.stroke(path(hole.vertices, point), with: .color(.primary.opacity(0.3)), lineWidth: 0.5)
                }
            }
        }
        .accessibilityLabel("Mapa domu")
    }

    private func houseBounds(_ floors: [Workspace.Floor.State]) -> (minX: Int, minY: Int, maxX: Int, maxY: Int) {
        var minX = 0, minY = 0, maxX = 1, maxY = 1
        var first = true
        for floor in floors {
            let box = bbox(floor.room)
            if first {
                minX = box.minX
                minY = box.minY
                maxX = box.maxX
                maxY = box.maxY
                first = false
            } else {
                minX = min(minX, box.minX)
                minY = min(minY, box.minY)
                maxX = max(maxX, box.maxX)
                maxY = max(maxY, box.maxY)
            }
        }
        return (minX, minY, maxX, maxY)
    }

    private func path(_ vertices: [Vertex], _ point: (Vertex) -> CGPoint) -> Path {
        var p = Path()
        guard let first = vertices.first else { return p }
        p.move(to: point(first))
        for v in vertices.dropFirst() {
            p.addLine(to: point(v))
        }
        p.closeSubpath()
        return p
    }
}
