import ComposableArchitecture2
import PlnFlrCapture
import SwiftUI

@main
struct PlnFlrMacApp: App {
    static let store = Store(initialState: Workspace.State()) {
        Workspace()
    }

    var body: some Scene {
        WindowGroup {
            WorkspaceView(store: Self.store)
                #if os(macOS)
                .frame(minWidth: 880, minHeight: 640)
                #endif
        }
        #if os(macOS)
        .windowResizability(.contentMinSize)
        #endif
    }
}
