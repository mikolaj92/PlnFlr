import ComposableArchitecture2
import PlnFlrCapture
import SwiftUI

@main
struct PlnFlrMacApp: App {
    static let store = Store(initialState: Plan.State()) {
        Plan()
    }

    var body: some Scene {
        WindowGroup {
            PlanView(store: Self.store)
                #if os(macOS)
                .frame(minWidth: 720, minHeight: 640)
                #endif
        }
        #if os(macOS)
        .windowResizability(.contentMinSize)
        #endif
    }
}
