import AppKit
import ComposableArchitecture2
import PlnFlrLayout
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
