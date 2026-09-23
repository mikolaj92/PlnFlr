# PlnFlr

Plan ułożenia podłogi. Z obrysu pomieszczenia (prostokąt, L, dowolny wielokąt z otworami) i wymiaru deski albo kafelka liczy dylatację, siatkę, docinki, BOM i pokazuje całą instalację.

Stack: Vapor 5 (`5.0.0-beta.2`) + HTMX + Alpine + Basecoat (app-factory v0.7.3 assets in `Web/Public`). Kernel: `PlnFlrLayout`. Capture: TCA26.

## Run

```bash
swift test --package-path Kernel
swift test --package-path Web
swift run --package-path Web PlnFlrServe --port 8004 --hostname 0.0.0.0
# http://127.0.0.1:8004
# live: https://plnflr.patryk.it
swift test --package-path App
swift run --package-path App PlnFlrApp
```

v0.1: lista pokoi jednego otwartego użytkownika. User podaje obrys, kąt i ewentualną podziałkę (np. pół kafelki, pół panele) albo wgrywa skan RoomPlan (USDZ). Serwer liczy dylatację, siatkę, docinki, odcięcia na progach (listwa), BOM i kolejność. Bez kont.

## Native app (local)

Native onboarding, local project autosave and StoreKit Pro work live under `App/`.
Open `App/PlnFlrWorkspace.xcworkspace` for the macOS/iOS app target and local StoreKit configuration.
See [App/README.md](App/README.md) for testing, current environment blockers, and the free-room policy.
No shared web/native accounts or entitlements. No TestFlight deployment yet.

## Live

LaunchAgent `dev.plnflr.api` on mini-m4-0 (`0.0.0.0:8004`). Caddy CT109 reverse-proxies `plnflr.patryk.it`. After merge to `main`, restart the unit:

```bash
launchctl kickstart -k "gui/$(id -u)/dev.plnflr.api"
curl -fsS http://127.0.0.1:8004/healthz
```
