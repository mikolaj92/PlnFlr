# PlnFlr

Mapa naszego domu, budowana razem z nami — od skanów i pomiarów, przez planowanie prac, po dokumentowanie tego, co zostało wykonane. Podłogi są pierwszym zastosowaniem, nie granicą produktu.

## Kierunek produktu

Punktem wyjścia jest skanowanie i poznawanie przestrzeni domu. Mapa ma być stopniowo uzupełniana i poprawiana przez użytkownika w trakcie budowy, remontu i użytkowania, a nie być jednorazowym wynikiem skanu.

Na tej samej mapie docelowo będziemy rozmieszczać, planować i dokumentować:

- podłogi i inne elementy wykończenia;
- instalacje wodne i kanalizacyjne;
- instalacje elektryczne;
- instalacje powietrzne i wentylacyjne;
- kolejne rodzaje instalacji i wyposażenia, w miarę potrzeb.

To warstwy jednego projektu domu, powiązane ze wspólną przestrzenią, nie osobne, niepowiązane plany. Stan istniejący i wykonany powinien być odróżnialny od zamierzeń. Skan jest źródłem geometrii — nie oznacza automatycznego rozpoznania ukrytych instalacji.

**Stan obecny:** aplikacja natywna importuje istniejące skany RoomPlan USDZ albo przyjmuje wymiary prostokątnego pokoju, zapisuje projekty lokalnie i planuje podłogi. Nie ma jeszcze własnego interfejsu skanowania kamerą ani edytorów pozostałych instalacji. Powyższy kierunek nie jest listą już dostarczonych funkcji.

Obecne drzewo `Workspace → Project → Scan + Floor` opisuje pierwszy etap. `Project` jest miejscem dalszego rozwoju mapy domu; przyszłe instalacje nie powinny być modelowane jako rodzaje podłogi. Nie dodajemy teraz pustych modułów ani nowego schematu danych na zapas.

## Planowanie podłóg — pierwszy etap

Z obrysu pomieszczenia (prostokąt, L, dowolny wielokąt z otworami) i wymiaru deski albo kafelka kernel liczy dylatację, siatkę, docinki, BOM i pokazuje cały układ podłogi.

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
