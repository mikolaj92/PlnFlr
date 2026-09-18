import ComposableArchitecture2
import PlnFlrLayout
import SwiftUI

public struct PlanView: View {
    @Bindable public var store: StoreOf<Plan>

    public init(store: StoreOf<Plan>) {
        self.store = store
    }

    public var body: some View {
        Form {
            Section("Pokój") {
                TextField("Szerokość m", text: $store.widthM)
                TextField("Długość m", text: $store.heightM)
                TextField("Dylatacja mm", text: $store.expansionMm)
            }
            Section("Deska") {
                TextField("Długość m", text: $store.plankLengthM)
                TextField("Szerokość m", text: $store.plankWidthM)
            }
            Button("Ułóż") {
                store.send(.layButtonTapped)
            }
            if let message = store.error {
                Text(message)
            }
            if let plan = store.plan {
                Text("Sztuki \(plan.bom.pieces) · deski \(plan.bom.fullBoards) · paczki \(plan.bom.packs.map(String.init) ?? "—")")
                Text(plan.rationalePl)
                FloorCanvas(plan: plan)
                    .frame(minHeight: 360)
            }
        }
        .padding()
        .navigationTitle("PlnFlr")
    }
}
