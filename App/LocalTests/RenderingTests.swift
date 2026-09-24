import AppKit
import ComposableArchitecture2
import PlnFlrLayout
import SceneKit
import SwiftUI
import XCTest
@testable import PlnFlrCapture

@MainActor
final class RenderingTests: XCTestCase {
    func testWelcomeAndPlanRenderLocally() throws {
        let welcomeStore = Store(initialState: Workspace.State()) { Workspace() }
        try capture(WelcomeView(store: welcomeStore).frame(width: 700, height: 740), name: "onboarding")
        var floor = Workspace.Floor.State(id: UUID(), name: "Salon", room: try rectangle(widthMm: 4000, heightMm: 3000))
        floor.plan = try floor.makePlan()
        let floorStore = Store(initialState: floor) { Workspace.Floor() }
        try capture(FloorView(store: floorStore, onPlan: {}).padding(24).frame(width: 700, height: 1080), name: "plan")
        var state = Workspace.State()
        state.proProduct = .init(displayPrice: "49,99 zł")
        try capture(ProView(store: Store(initialState: state) { Workspace() }).frame(width: 540, height: 740), name: "pro")
    }

    func testFloorSceneUsesBothFinishGroupsAndAnInteractiveCamera() throws {
        let floor = Workspace.Floor.State(id: UUID(), name: "Salon", room: try rectangle(widthMm: 4000, heightMm: 3000))
        let plan = try floor.makePlan()
        let scene = Floor3DScene.make(plan: plan, finish: .oak)
        let floorNode = try XCTUnwrap(scene.rootNode.childNodes.first { $0.name == "floor" })
        let finishNodes = floorNode.childNodes.filter { $0.name?.hasPrefix("floor.finish.") == true }

        XCTAssertEqual(finishNodes.count, 2)
        XCTAssertTrue(finishNodes.allSatisfy { $0.geometry != nil })
        let walnutScene = Floor3DScene.make(plan: plan, finish: .walnut)
        let walnutNode = try XCTUnwrap(walnutScene.rootNode.childNodes.first { $0.name == "floor" }?.childNodes.first { $0.name == "floor.finish.0" })
        let oakNode = try XCTUnwrap(floorNode.childNodes.first { $0.name == "floor.finish.0" })
        XCTAssertNotEqual(walnutNode.geometry?.materials.first?.diffuse.contents as? NSColor,
                          oakNode.geometry?.materials.first?.diffuse.contents as? NSColor)
        XCTAssertNotNil(scene.rootNode.childNodes.first { $0.name == "floor.camera" }?.camera)
        XCTAssertTrue(scene.rootNode.childNodes.contains { $0.camera != nil })
        let rendered = SCNRenderer(device: nil, options: nil)
        rendered.scene = scene
        let image = rendered.snapshot(atTime: 0, with: CGSize(width: 600, height: 400), antialiasingMode: .multisampling4X)
        let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let woodPixels = (0..<bitmap.pixelsWide).reduce(into: 0) { count, x in
            for y in 0..<bitmap.pixelsHigh {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                if color.redComponent > color.greenComponent * 1.05,
                   color.greenComponent > color.blueComponent * 1.05,
                   color.redComponent < 0.95,
                   color.greenComponent < 0.9 {
                    count += 1
                }
            }
        }
        XCTAssertGreaterThan(woodPixels, 100)
    }

    func testTilePreviewUsesStoneColorsInsteadOfWoodFinishColors() throws {
        var floor = Workspace.Floor.State(id: UUID(), name: "Łazienka", room: try rectangle(widthMm: 3000, heightMm: 3000))
        floor.material = .tile
        floor.plankLengthM = "0.6"
        floor.plankWidthM = "0.6"
        let plan = try floor.makePlan()
        let scene = Floor3DScene.make(plan: plan, finish: .oak, material: .tile)
        let floorNode = try XCTUnwrap(scene.rootNode.childNodes.first { $0.name == "floor" })
        let tiles = try XCTUnwrap(floorNode.childNodes.first { $0.name == "floor.finish.0" })
        let tileColor = try XCTUnwrap(tiles.geometry?.materials.first?.diffuse.contents as? NSColor)
        let wood = NSColor(red: 0.78, green: 0.60, blue: 0.37, alpha: 1)
        XCTAssertNotEqual(tileColor, wood)
        let canvas = FloorCanvas(plan: plan, finish: .oak, material: .tile)
        XCTAssertEqual(canvas.material, .tile)
        XCTAssertEqual(plan.bom.kind, .tile)
    }

    func testDarkCanvasHoleUsesBackgroundInsteadOfWhitePaint() throws {
        let hole = try Ring([Vertex(1000, 1000), Vertex(2000, 1000), Vertex(2000, 2000), Vertex(1000, 2000)])
        let room = Room(try rectangle(widthMm: 3000, heightMm: 3000).outer, holes: [hole])
        let floor = Workspace.Floor.State(id: UUID(), name: "Salon", room: room)
        let plan = try floor.makePlan()
        let renderer = ImageRenderer(content: FloorCanvas(plan: plan).frame(width: 300, height: 300)
            .background(Color.black).environment(\.colorScheme, .dark))
        let image = try XCTUnwrap(renderer.cgImage)
        let bitmap = NSBitmapImageRep(cgImage: image)
        let color = try XCTUnwrap(bitmap.colorAt(x: 150, y: 150)?.usingColorSpace(.deviceRGB))
        XCTAssertLessThan(color.redComponent, 0.1)
        XCTAssertLessThan(color.greenComponent, 0.1)
        XCTAssertLessThan(color.blueComponent, 0.1)
    }

    private func capture<V: View>(_ view: V, name: String) throws {
        _ = NSApplication.shared
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, .light).background(Color.white))
        hosting.appearance = NSAppearance(named: .aqua)
        hosting.frame.size = hosting.fittingSize
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        XCTAssertGreaterThan(bitmap.pixelsWide, 500)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let directory = URL(fileURLWithPath: "/tmp/plnflr-local-previews")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: directory.appendingPathComponent(name + ".png"))
    }
}
