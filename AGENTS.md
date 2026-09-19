# PlnFlr agent notes

- Host is Vapor 5 (`Web/`, pin `5.0.0-beta.2`) on `0.0.0.0:8004`. Kernel is `Kernel/` (`PlnFlrLayout`). App is `App/` (`PlnFlrCapture` TCA26 + `PlnFlrApp`). Platforms: iOS 26.4 / macOS 26.4 only. Do not copy Basecoat/HTMX/Alpine from npm; ship the app-factory v0.7.3 files in `Web/Public/static/platform`.
- Geometry is integer millimetres. Parse metres with `Decimal`. Live kernel is Swift `PlnFlrLayout`. Python/`pyclipper` is leftover, not live. TCA26 is Capture UI state, not layout math. TCA26 is private: pin `git@github.com:pointfreeco/TCA26.git`.
- Room is a polygon with holes. Rectangle and L are constructors, not separate engines.
- Grid is axis-aligned rectangles. Clip each board/tile to the inset polygon. Visual preview of the whole install is Definition of Done.
- TDD. `swift test --package-path Kernel` and `swift test --package-path Web`. No npm, no shapely, no numpy. RoomPlan USDZ is the investment scan: parse USDA meshes in stdlib, no pxr.
- Live deploy is part of Done. `https://plnflr.patryk.it` is LaunchAgent `dev.plnflr.api` on mini-m4-0 (`0.0.0.0:8004`). Merge ≠ reload. After merge: fast-forward this worktree, `launchctl kickstart -k "gui/$(id -u)/dev.plnflr.api"`, prove `http://127.0.0.1:8004/healthz` and changed routes.
- Authorship is `mikolaj92`. No AI co-author trailers.
