# PlnFlr agent notes

- Host FastAPI on `app-factory` product_shell. Do not copy Basecoat/HTMX/Alpine. Pin `app-factory` git tag `v0.6.22`.
- Geometry is integer millimetres. Parse metres with `Decimal`. Kernel: `pyclipper`.
- Room is a polygon with holes. Rectangle and L are constructors, not separate engines.
- Grid is axis-aligned rectangles. Clip each board/tile to the inset polygon. Visual preview of the whole install is Definition of Done.
- TDD. `uv run pytest`. No npm, no shapely, no numpy, no 3D parser until a real investment file exists.
- Live deploy is part of Done. `https://plnflr.patryk.it` is LaunchAgent `dev.plnflr.api` on mini-m4-0 (`0.0.0.0:8004`). Merge ≠ reload. After merge: fast-forward this worktree, `launchctl kickstart -k "gui/$(id -u)/dev.plnflr.api"`, prove `http://127.0.0.1:8004/healthz` and changed routes.
- Authorship is `mikolaj92`. No AI co-author trailers.
