import Vapor

public struct Health: Content {
    public var ok: String

    public init(ok: String) {
        self.ok = ok
    }
}
