import ComposableArchitecture2
import PlnFlrCapture
import PlnFlrLayout
import Testing

@Test func layButtonTappedProducesPlan() async throws {
    let room = try rectangle(widthMm: 4000, heightMm: 3000)
    let spec = PlankSpec(lengthMm: 1383, widthMm: 156, boardsPerPack: 8)
    let rules = LayoutRules(expansionMm: 10)
    let expected = try layoutFloor(
        room,
        zones: [Zone(kind: .plank, plank: spec)],
        rules: rules
    )
    let store = await TestStoreActor(
        initialState: Plan.State(
            heightM: "3",
            plankLengthM: "1.383",
            plankWidthM: "0.156",
            widthM: "4"
        )
    ) {
        Plan()
    }
    await store.send(.layButtonTapped) {
        $0.plan = expected
    }
}
