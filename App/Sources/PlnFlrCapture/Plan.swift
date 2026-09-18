import ComposableArchitecture2
import PlnFlrLayout

@Feature
public struct Plan {
    public struct State {
        public var error: String?
        public var expansionMm: String
        public var heightM: String
        public var plan: LayoutPlan?
        public var plankLengthM: String
        public var plankWidthM: String
        public var widthM: String

        public init(
            error: String? = nil,
            expansionMm: String = "10",
            heightM: String = "3",
            plan: LayoutPlan? = nil,
            plankLengthM: String = "1.383",
            plankWidthM: String = "0.156",
            widthM: String = "4"
        ) {
            self.error = error
            self.expansionMm = expansionMm
            self.heightM = heightM
            self.plan = plan
            self.plankLengthM = plankLengthM
            self.plankWidthM = plankWidthM
            self.widthM = widthM
        }
    }

    public enum Action {
        case layButtonTapped
    }

    public init() {}

    public var body: some Feature {
        Update { state, action in
            switch action {
            case .layButtonTapped:
                do {
                    state.error = nil
                    state.plan = try Self.layout(from: state)
                } catch {
                    state.error = String(describing: error)
                    state.plan = nil
                }
            }
        }
    }

    public static func layout(from state: State) throws -> LayoutPlan {
        let expansion = Int(state.expansionMm) ?? 10
        return try layoutFloor(
            try rectangle(widthMm: try metresToMm(state.widthM), heightMm: try metresToMm(state.heightM)),
            zones: [
                Zone(
                    kind: .plank,
                    plank: PlankSpec(
                        lengthMm: try metresToMm(state.plankLengthM),
                        widthMm: try metresToMm(state.plankWidthM),
                        boardsPerPack: 8
                    )
                ),
            ],
            rules: LayoutRules(expansionMm: expansion)
        )
    }
}
