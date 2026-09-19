import ComposableArchitecture2
import PlnFlrLayout
import SwiftUI
import UniformTypeIdentifiers

public struct HouseView: View {
    @Bindable public var store: StoreOf<House>

    public init(store: StoreOf<House>) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            List(store.rooms, selection: $store.selectedID) { item in
                Text(item.name)
                    .tag(item.id)
            }
            .navigationTitle("Dom")
        } detail: {
            VStack(alignment: .leading, spacing: 12) {
                HouseCanvas(rooms: store.rooms, selectedID: store.selectedID)
                    .frame(minHeight: 360)
                HStack {
                    Button("Importuj USDZ") { $store.isImporting.wrappedValue = true }
                    TextField("Cięcie m", text: $store.splitAtM)
                        .frame(width: 90)
                    Picker("Oś", selection: $store.splitAxis) {
                        Text("X").tag(SplitAxis.x)
                        Text("Y").tag(SplitAxis.y)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                    Button("Podziel") { store.send(.splitSelectedButtonTapped) }
                        .disabled(store.selectedID == nil)
                }
                if let message = store.error {
                    Text(message)
                }
            }
            .padding()
        }
        .fileImporter(
            isPresented: $store.isImporting,
            allowedContentTypes: [.usdz]
        ) { result in
            importUsdz(result)
        }
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

struct HouseCanvas: View {
    var rooms: [House.RoomItem]
    var selectedID: UUID?

    var body: some View {
        Canvas { context, size in
            let bounds = houseBounds(rooms)
            let width = max(CGFloat(bounds.maxX - bounds.minX), 1)
            let height = max(CGFloat(bounds.maxY - bounds.minY), 1)
            let scale = min(size.width / width, size.height / height)
            func point(_ v: Vertex) -> CGPoint {
                CGPoint(
                    x: CGFloat(v.xMm - bounds.minX) * scale,
                    y: size.height - CGFloat(v.yMm - bounds.minY) * scale
                )
            }
            for item in rooms {
                let selected = item.id == selectedID
                context.fill(
                    path(item.room.outer.vertices, point),
                    with: .color(selected ? Color.orange.opacity(0.35) : Color.secondary.opacity(0.15))
                )
                context.stroke(
                    path(item.room.outer.vertices, point),
                    with: .color(selected ? .orange : .primary.opacity(0.5)),
                    lineWidth: selected ? 2 : 1
                )
                for hole in item.room.holes {
                    context.fill(path(hole.vertices, point), with: .color(.white))
                    context.stroke(path(hole.vertices, point), with: .color(.primary.opacity(0.3)), lineWidth: 0.5)
                }
            }
        }
        .accessibilityLabel("Mapa domu")
    }

    private func houseBounds(_ rooms: [House.RoomItem]) -> (minX: Int, minY: Int, maxX: Int, maxY: Int) {
        var minX = 0, minY = 0, maxX = 1, maxY = 1
        var first = true
        for item in rooms {
            let box = bbox(item.room)
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
