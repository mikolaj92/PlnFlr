# PlnFlr agent notes

- Host FastAPI on the platform BOM: `app-factory` `v0.7.3`, `my-auth` `v0.5.6`, and `my-usermanager` `v0.6.7`. Do not copy Basecoat/HTMX/Alpine.
- Geometry is integer millimetres. Parse metres with `Decimal`. Live kernel: `pyclipper`. Swift kernel: `Kernel/` (`PlnFlrLayout`). App: `App/` (`PlnFlrCapture` TCA26 + `PlnFlrApp`). Platforms: iOS 26 / macOS 26 only (not 17). Vapor 5 is the future web host, not the kernel. TCA26 is Capture UI state, not layout math. TCA26 is private: pin `git@github.com:pointfreeco/TCA26.git`.
- Room is a polygon with holes. Rectangle and L are constructors, not separate engines.
- Grid is axis-aligned rectangles. Clip each board/tile to the inset polygon. Visual preview of the whole install is Definition of Done.
- TDD. `uv run pytest` and `swift test --package-path Kernel`. No npm, no shapely, no numpy. RoomPlan USDZ is the investment scan: parse USDA meshes in stdlib, no pxr.
- Live deploy is part of Done. `https://plnflr.patryk.it` is LaunchAgent `dev.plnflr.api` on mini-m4-0 (`0.0.0.0:8004`). Merge ≠ reload. After merge: fast-forward this worktree, `launchctl kickstart -k "gui/$(id -u)/dev.plnflr.api"`, prove `http://127.0.0.1:8004/healthz` and changed routes.
- Authorship is `mikolaj92`. No AI co-author trailers.
