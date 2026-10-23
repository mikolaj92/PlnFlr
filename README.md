# PlnFlr

PlnFlr importuje skany RoomPlan USDZ, zapisuje projekty lokalnie i planuje podłogi. Na iOS obsługuje także skanowanie wielu pokoi w jednej sesji Apple RoomPlan. Opis aplikacji natywnej, zapisu danych i zakupów: [App/README.md](App/README.md). Kompas produktu: [SOUL.md](SOUL.md), nie lista wdrożonych funkcji.

## Skany i mapa

Przebieg RoomPlan dotyczy jednej kondygnacji. `StructureBuilder` składa pokoje, a projekt zachowuje oryginalne modele i wynik. Skan z aparatu nie wyprowadza jeszcze podłóg. Przepływ wymaga weryfikacji na fizycznym urządzeniu; kompilacja i testy logiki/zapisu nie potwierdzają zgodności położenia pokoi z pomiarami.

Wspólny podgląd skanów obsługuje ręczne przesunięcie, obrót i wysokość. Nie wyrównuje automatycznie osobnych sesji ani nie usuwa zdublowanych ścian. Wydzielanie `ModelPart` wybiera węzły bez zmiany ich położenia; nie jest cięciem geometrii. Importer podłóg nie jest ogólnym edytorem USDZ. Warianty USDZ wymagają sprawdzenia na rzeczywistych plikach.

Projekt zawiera skany, podłogi, części i meble, ale nie ma trwałego rejestru kondygnacji ani relacji pokoi do kondygnacji. `storey` jest etykietą podłogi. Wybór pokoju/kondygnacji/domu w planowaniu korzysta z podłóg, nie z niezależnej mapy bazowej. Zapis mebli i proste bryły nie zapewniają powiązania obiektów z pokojem, kondygnacją lub skanem.

Warunek gotowości tych zakresów: zapisać i otworzyć dom z dwiema kondygnacjami i pokojem bez podłogi. Bez odczytu `floors`/`floorVariants` trzeba uzyskać trwałe identyfikatory pokoi i jednoznacznych rodziców. Wybór pokoju, kondygnacji i domu musi zwracać właściwe zbiory oraz zgodny podgląd źródeł, także po zmianie wariantu podłogi. Znany punkt i wysokość na obu kondygnacjach trzeba sprawdzić względem pomiarów. Korekta skanu i ponowne otwarcie muszą zachować położenie powiązanych obiektów oraz oryginalne źródła. Brak rejestru i relacji blokuje spełnienie tego warunku; test zapisu kolekcji mebli go nie zastępuje.

Odłączenie części i cofanie nie mogą niszczyć oryginałów. Eksport części lub całości do USDZ nie zastępuje źródeł.

## Podłogi

Z obrysu pomieszczenia (prostokąt, L, dowolny wielokąt z otworami) i wymiaru deski albo kafelka kernel liczy dylatację, siatkę, docinki i zestawienie materiałów (BOM). Podgląd pokazuje cały układ podłogi. Aplikacja natywna przyjmuje ręcznie prostokąt albo importuje powierzchnie z USDZ.

Uproszczony podgląd 2D/3D korzysta z elementów `LayoutPlan`. Kolorystyka dąb/orzech lub neutralna kamienna nie odwzorowuje konkretnego produktu. Podgląd nie renderuje skanu RoomPlan w tle i nie podnosi dokładności pomiarów. Wizualizacja, geometria, BOM i koszt muszą dotyczyć tego samego wariantu; dokładność ilości nie może przekraczać dokładności źródłowych pomiarów.

## Granica bezpieczeństwa

Skan geometrii nie odkrywa instalacji ukrytych w ścianie. Ich trasy wymagają jawnego źródła: pomiaru, odkrycia lub dokumentacji. Dane potwierdzone trzeba odróżniać od przybliżonych, niezweryfikowanych i planowanych. Brak danych nie oznacza braku instalacji ani gwarancji bezpieczeństwa wiercenia. Aplikacja nie ma edytorów pozostałych instalacji ani obliczeń hydraulicznych, elektrycznych czy wentylacyjnych.

## Uruchomienie i kontrole lokalne

Stack: Vapor 5 (`5.0.0-beta.2`), HTMX, Alpine i Basecoat (app-factory v0.7.3 w `Web/Public/static/platform`). Kernel: `PlnFlrLayout`. Aplikacja natywna: TCA26, iOS/macOS 26.4.

```bash
swift test --package-path Kernel
swift test --package-path Web
swift test --package-path App
swift run --package-path Web PlnFlrServe --port 8004 --hostname 0.0.0.0
# http://127.0.0.1:8004
swift run --package-path App PlnFlrApp
```

Do testów platformowych i zakupów otwórz `App/PlnFlrWorkspace.xcworkspace`. Polecenia oraz ograniczenia weryfikacji są w [App/README.md](App/README.md#testy). Web i aplikacja natywna nie współdzielą kont ani uprawnień. Nie ma wdrożenia TestFlight.

Host Python udostępnia pokoje wyłącznie właścicielowi wskazanemu przez sesję adaptera (`PlatformUser.user_id`). Gość jest przekierowywany do logowania bez odczytu i zapisu pokojów. Historyczne dane `local` pozostają w magazynie i nie są przypisywane kontom. Host wymaga konfiguracji adapterów tożsamości oraz mapowania zweryfikowanej sesji przez `current_user`; bez niego trasy pokojów odmawiają dostępu.

## Live

`https://plnflr.patryk.it`: LaunchAgent `dev.plnflr.api` na mini-m4-0 (`0.0.0.0:8004`), reverse proxy Caddy CT109. Po scaleniu do `main` trzeba zaktualizować wdrażany katalog i zrestartować usługę. Samo scalenie nie przeładowuje procesu. Sprawdź zdrowie usługi oraz zmienione trasy:

```bash
launchctl kickstart -k "gui/$(id -u)/dev.plnflr.api"
curl -fsS http://127.0.0.1:8004/healthz
```
