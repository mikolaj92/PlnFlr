# PlnFlr

Aplikacja zapisuje skany i projekty lokalnie oraz oblicza układ podłogi. Zasady produktu i granice bezpieczeństwa opisuje [SOUL.md](SOUL.md).

## Planowanie podłóg

Kernel `PlnFlrLayout` przyjmuje wielokąty z otworami. Oblicza dylatację, siatkę, docinki, zestawienie materiałów (BOM) i kolejność układania. Geometria używa całkowitych milimetrów.

Aplikacja natywna importuje RoomPlan USDZ i przyjmuje wymiary prostokątnego pokoju. Na iOS zapisuje także źródłowe pokoje oraz CapturedStructure z sesji RoomPlan. Skan z aparatu nie tworzy powierzchni podłogowych.

Projekt zachowuje źródła, ręczne położenia skanów, historię korekt i warianty podłogi. Model kondygnacji i przypisań nie jest dostępny; tekstowe pole `storey` nie stanowi takiego modelu.

Podglądy pojedynczej podłogi 2D i 3D korzystają z elementów `LayoutPlan`. Nie potwierdzają dokładności pomiarów ani bezpieczeństwa wiercenia.

## Uruchomienie i kontrole

Web używa Vapor 5 (`5.0.0-beta.2`), HTMX, Alpine i Basecoat z plików app-factory v0.7.3 w `Web/Public/static/platform`. Aplikacja natywna używa TCA26.

```sh
swift test --package-path Kernel
swift test --package-path Web
swift test --package-path App
swift run --package-path Web PlnFlrServe --port 8004 --hostname 0.0.0.0
uv sync --frozen --group dev
uv run --frozen pytest -q
uv run --frozen ruff check src tests
git diff --check
```

Uruchomienie aplikacji, lokalny zapis, zasady darmowego pokoju i testy StoreKit opisuje [App/README.md](App/README.md).

Host Python udostępnia pokoje wyłącznie właścicielowi wskazanemu przez sesję adaptera (`PlatformUser.user_id`). Gość jest przekierowywany do logowania bez odczytu i zapisu pokojów. Bez mapowania zweryfikowanej sesji przez `current_user` trasy odmawiają dostępu.

## Host Web

LaunchAgent `dev.plnflr.api` na mini-m4-0 nasłuchuje na `0.0.0.0:8004`. Caddy CT109 obsługuje `plnflr.patryk.it`. Po scaleniu zmiany hosta przeładowanie i kontrola działają tak:

```sh
launchctl kickstart -k "gui/$(id -u)/dev.plnflr.api"
curl -fsS http://127.0.0.1:8004/healthz
```
