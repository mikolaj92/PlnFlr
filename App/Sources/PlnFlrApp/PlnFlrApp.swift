import ComposableArchitecture2
import PlnFlrCapture
import SwiftUI

@main
struct PlnFlrMacApp: App {
    static let house = Store(initialState: House.State()) {
        House()
    }
    static let plan = Store(initialState: Plan.State()) {
        Plan()
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Dom", systemImage: "house") {
                    HouseView(store: Self.house)
                }
                Tab("Układ", systemImage: "square.grid.3x3") {
                    PlanView(store: Self.plan)
                }
            }
            #if os(macOS)
            .frame(minWidth: 720, minHeight: 640)
            #endif
        }
        #if os(macOS)
        .windowResizability(.contentMinSize)
        #endif
    }
}
