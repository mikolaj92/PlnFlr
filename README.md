# PlnFlr

PlnFlr importuje skany RoomPlan USDZ, zachowuje źródła i planuje podłogi. Kompas produktu i granice bezpieczeństwa opisuje [SOUL.md](SOUL.md).

## Aplikacja natywna

Otwórz `App/PlnFlrWorkspace.xcworkspace`. Aplikacja działa lokalnie na iOS/macOS 26.4 i zapisuje projekty automatycznie. Pro pochodzi ze zweryfikowanych transakcji StoreKit, nie z projektu.

Na iOS RoomPlan zbiera wiele pokoi w jednej sesji i składa je przez `StructureBuilder`. Na Macu dostępny jest import USDZ. Osobne sesje wymagają ustawienia transformacji; wspólne położenie nie jest automatycznie gwarantowane.

Mapa 3D pokazuje skany, obrysy podłóg, ściany, trasy instalacji i prostopadłościany mebli. Edytor mebli przyjmuje wymiary i środek bryły w całkowitych milimetrach oraz obrót w stopniach. Ukrycie zachowuje rekord. Cofanie dotyczy wyłącznie mebli.

Zakresy pokojów i kondygnacji korzystają obecnie z powierzchni podłogowych i ich etykiet. Nie reprezentują jeszcze powiązań pokojów i kondygnacji bazowego skanu. Skany, ściany i instalacje widać tylko w zakresie domu. Nie jest to kompletna obsługa zakresów wspólnej mapy.

Instalacje mają jawne źródło i pewność danych. Brak danych nie potwierdza bezpieczeństwa wiercenia. Meble nie zmieniają geometrii ani BOM podłogi.

Opis uruchamiania, zapisu i ograniczeń testów: [App/README.md](App/README.md). Brak kont PlnFlr, synchronizacji chmurowej i wdrożenia TestFlight.

## Planowanie podłóg

Kernel `PlnFlrLayout` przyjmuje wielokąt z otworami i wymiary deski lub kafelka. Liczy dylatację, siatkę, docinki, BOM i kolejność układania. Prostokąt i L są konstruktorami obrysu.

Podgląd 2D/3D elementów pochodzi z `LayoutPlan`. Kolorystyka dąb/orzech nie odwzorowuje produktu i nie zmienia BOM. Podgląd nie zwiększa dokładności pomiarów.

Host: Vapor 5 (`5.0.0-beta.2`), HTMX, Alpine i Basecoat z app-factory v0.7.3 w `Web/Public`. Aplikacja natywna używa TCA26.

```sh
swift test --package-path Kernel
swift test --package-path Web
swift test --package-path App
swift run --package-path Web PlnFlrServe --port 8004 --hostname 0.0.0.0
swift run --package-path App PlnFlrApp
```

Host Python udostępnia pokoje wyłącznie właścicielowi wskazanemu przez sesję adaptera (`PlatformUser.user_id`). Gość jest przekierowywany do logowania bez odczytu i zapisu pokojów. Historyczne dane `local` pozostają w magazynie. Bez mapowania zweryfikowanej sesji przez `current_user` trasy pokojów odmawiają dostępu.

## Serwer

`https://plnflr.patryk.it`: LaunchAgent `dev.plnflr.api` na mini-m4-0 (`0.0.0.0:8004`), przez Caddy CT109. Scalenie kodu nie przeładowuje procesu.

```sh
launchctl kickstart -k "gui/$(id -u)/dev.plnflr.api"
curl -fsS http://127.0.0.1:8004/healthz
```
