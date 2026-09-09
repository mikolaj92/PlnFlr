# Approach plan

<!-- lokay-approach source=deterministic repo=mikolaj92/PlnFlr issue=19 -->

Repository: `mikolaj92/PlnFlr`  
Issue: #19 — Pin BOM v0.6.12 / v0.4.6 / v0.5.8 (jedna generacja)

## Goal

Host musi pinować jedną bieżącą generację BOM, bez rollbacku chrome. `origin/main` ma już `app-factory` **v0.6.22**. COMPAT.md na `app-factory@origin/main` ma preferred **v0.6.22 / my-auth v0.5.4 / my-usermanager v0.6.5**. Nie wracać do v0.6.12 / v0.4.6 / v0.5.8.

## Files likely touched

- `pyproject.toml`
- `uv.lock`
- `README.md`
- `AGENTS.md`
- `v0.6.22`
- `tool.uv.sources`

## Test plan

- `dependencies` ma `app-factory[platform]`, `my-auth[fastapi-htmx]`, `my-usermanager[fastapi-htmx,myauth]`
- `tool.uv.sources` pinuje tagi git: app-factory **v0.6.22**, my-auth **v0.5.4**, my-usermanager **v0.6.5** (nie `path =`, nie `branch = main`)
- `override-dependencies` tylko `app-factory[platform]` (bez override my-auth)
- `uv.lock` zgadza się z tymi tagami
- `README.md` i `AGENTS.md` opisują ten wiersz, nie v0.5.19
- `uv run pytest -q` przechodzi na nowym pinie

## Non-goals

- Wiring `install_identity_adapters` i konta zamiast `OPEN_USER_ID` (osobne ticketty). Silnik dylatacji / SVG. Szablony `card-header` (osobny ticket).

## Notes

- Trust intentional issue; this plan is evidence for later review, not a human gate.
- Coding agent may refine details but should stay on the stated goal and non-goals.
- Collector boundary: if implementation introduces unbounded collection, ship only a bounded collector patch that starts durably in the background after merge. The coding agent and lokay must not populate data or wait for collection to finish.
