# PlnFlr

Mapa naszego domu, budowana razem z nami — od skanów i pomiarów, przez planowanie prac, po dokumentowanie tego, co zostało wykonane. Zaczynamy od skanów całego domu i poszczególnych pomieszczeń; podłogi są kolejnym etapem, nie granicą produktu.

## Kierunek produktu

Punktem wyjścia jest skanowanie i poznawanie przestrzeni domu. Mapa ma być stopniowo uzupełniana i poprawiana przez użytkownika w trakcie budowy, remontu i użytkowania, a nie być jednorazowym wynikiem skanu.

Kolejność rozwoju produktu:

1. **Skany całego domu i poszczególnych pomieszczeń** — budowanie i uzupełnianie wspólnej mapy domu. To bieżący priorytet.
2. **Podłogi** — planowanie ich układu na zbudowanej mapie.
3. **Wykończenia ścian i wnętrza** — zmiana kolorów i materiałów na tej samej mapie 3D, po podłogach.
4. **Instalacje** — rozmieszczanie, planowanie i dokumentowanie instalacji wodnych, kanalizacyjnych, elektrycznych, powietrznych, wentylacyjnych i innych.
5. **Meble i wyposażenie** — rozmieszczanie ich na tej samej mapie domu.

Bieżący zakres prac obejmuje **1 i 2: skany domu i pomieszczeń, następnie podłogi**. Potem mapa 3D rozszerzy się o wykończenia ścian, instalacje i wyposażenie. Istniejący kod planowania podłóg nie oznacza, że etap skanowania całego domu jest już domknięty.

### Cel produktu — SOUL

**Każdy dom powinien mieć swój wierny, trwały model 3D**, widoczny w aplikacji i rozwijany jako mapa rzeczywistego domu. Jeden model pozwala pracować na wybranym zakresie: pojedynczym pomieszczeniu, kondygnacji albo całym domu — na przykład zaplanować podłogę w jednym pokoju lub policzyć ją dla całego domu.

Zmiana zaczyna się w modelu, nie od razu w domu. Właściciel zachowuje stan obecny, tworzy wariant podłogi, ogląda go przestrzennie w pokoju i kontekście domu, porównuje materiały i układy, a następnie oblicza rzeczywiste ilości materiału dla tego samego wariantu. Wizualizacja ma pomagać wyobrazić sobie efekt przed remontem — jak konfigurator wnętrza, np. IKEA. BOM pochodzi z geometrii i parametrów wybranego materiału, a nie z dekoracyjnego obrazka; jego dokładność nie może przekraczać dokładności źródłowych pomiarów.

Docelowo tę samą mapę 3D będzie można rozszerzać o kolory i wykończenia ścian, udokumentowane instalacje wewnątrz ścian, a później meble i inne wyposażenie. To kolejne warstwy tego samego domu.

Test sensu produktu: przed wierceniem użytkownik wskazuje miejsce i głębokość, a aplikacja pokazuje udokumentowane instalacje, które mogą się tam znaleźć. **Skan geometrii nie odkrywa sam instalacji ukrytych w ścianie.** Trasy muszą być zapisane na podstawie pomiaru, odkrycia, dokumentacji lub innego jawnego źródła; mapa odróżnia potwierdzone dane od przybliżonych, niezweryfikowanych i planowanych. Brak danych nie oznacza braku instalacji ani gwarancji, że wiercenie jest bezpieczne.

Źródła i poprawki mają przetrwać. Dokładność jest ważniejsza niż pozorna kompletność. Pełny kompas produktu i kryteria są w [SOUL.md](SOUL.md).

### Podłogi — wizualizacja i rzeczywiste ilości

Podłoga nie jest tylko wynikiem BOM. Właściciel wybiera pokój, kondygnację lub dom na mapie, zmienia materiał i układ jako wariant, ogląda wizualizację, a następnie oblicza rzeczywiste ilości dla dokładnie tego wariantu. Stan istniejący pozostaje zachowany; projektowana zmiana nie nadpisuje go przed wykonaniem.

**Wymóg produktu:** podgląd ma pokazywać podłogę w kontekście rzeczywistej przestrzeni — docelowo w 3D, w stylu konfiguratora wnętrza. Wizualizacja, geometria i obliczenia muszą być spójne: wybór układu widoczny w podglądzie zasila BOM i koszt, a grafika nie sugeruje dokładności większej niż pomiary źródłowe. Pierwszy wycinek jest dostępny: po wyliczeniu planu można przełączyć uproszczony podgląd elementów z `LayoutPlan` na obracany widok 3D, wybrać kolorystykę dąb/orzech dla podłogi deskowej lub neutralną kamienną dla płytek. Nie jest to jeszcze konfigurator wnętrza całego pokoju: zapisany skan RoomPlan nie jest renderowany w tle, tekstury nie odwzorowują konkretnego produktu, a podgląd nie podnosi dokładności pomiarów.

### Skany — mapa bazowa i warunek rozpoczęcia mebli

**Wynik przeglądu kodu: warstwa mebli jest zablokowana przez brak relacji dom → kondygnacja → pokój w mapie bazowej.** Wspólny podgląd skanów nie zapewnia tego kontraktu. Istnieją już `FurnitureItem` i zapis mebli, ale nie potwierdzają gotowości zakresów.
- **Identyfikatory i relacje:** w [Workspace.swift](App/Sources/PlnFlrCapture/Workspace.swift) `Project.State.projectID: UUID` identyfikuje projekt, nie osobną encję domu; projekt zawiera `scans`, `floors`, `parts` i `furniture`. `Scan.State.scanID: UUID` identyfikuje źródło. Nie ma encji ani identyfikatora kondygnacji. `Floor.State.storey: String?` jest etykietą podłogi, nie relacją mapy. `floorID` identyfikuje powierzchnię roboczą, a `accessID` uprawnienie do obliczeń; żaden nie jest identyfikatorem pokoju bazowego.
- **Pokoje źródłowe:** [RoomPlanStructureSource.swift](App/Sources/PlnFlrCapture/RoomPlanStructureSource.swift) zachowuje oryginalne JSON-y Apple `CapturedRoom` i wynik `CapturedStructure`. `HouseScene.rooms(_:)` odczytuje ich `identifier` i dopasowuje identyfikatory elementów do nazw węzłów meshu. Zwraca tylko pokoje z dopasowanymi ścieżkami; nie tworzy trwałego rejestru pokoi ani przypisania do kondygnacji. `ModelPart.id: UUID` wskazuje wybraną część przez `scanID` i `nodePaths`, nie pokój lub kondygnację. Kernelowy [CapturedRoom](Kernel/Sources/PlnFlrLayout/RoomPlan.swift) to odrębny typ 2D bez identyfikatora; import USDZ tworzy nowe podłogi bez trwałego odwołania do pokoju źródłowego.
- **Układ współrzędnych:** [HouseScene.swift](App/Sources/PlnFlrCapture/HouseScene.swift) wczytuje mesh przez ModelIO. `ScanTransform` domyślnie jest tożsamościowy; zapisuje przesunięcie w całkowitych mm i obrót `yawDegrees`. W rendererze przesunięcie wynosi `(xMm, zMm, yMm)/1000` metrów, a obrót odbywa się wokół pionowej osi Y SceneKit. Tak samo mapowane są `ScenePoint`: X/Y to płaszczyzna, Z to wysokość; `FurnitureItem.origin` ustawia środek bryły. Mesh zachowuje układ źródła; kod nie ustanawia osobnego początku domu ani normalizacji dowolnego USDZ. `ScanPlacement` przechowuje ręczną korektę i poprzednią transformację, nie dowód zgodności skanów z pomiarem.
- **API i miejsca integracji:** `HouseScene.scans(_:selection:)` buduje scenę źródeł i zwraca błędy; `elements(_:)`, `rooms(_:)` oraz `validateSelection(_:paths:)` obsługują wybór części. W [WorkspaceView.swift](App/Sources/PlnFlrCapture/WorkspaceView.swift) `ScanSceneView` i edytor części korzystają z tych API. `Project.Action.extractPart`/`detachPart` oraz akcja skanu `setManualPlacementButtonTapped` zmieniają części i położenie. `FurnitureItem` i `HouseScene.scene(walls:routes:furniture:)` już tworzą proste bryły, lecz osobno od sceny skanów, bez relacji obiektu do pokoju, kondygnacji lub skanu. [WorkspaceArchive.ProjectRecord](App/Sources/PlnFlrCapture/WorkspaceArchive.swift) zapisuje te kolekcje; to miejsca przyszłej integracji, nie gotowe API zakresów mebli.
- **Zakresy niezależne od podłóg — blokada planowania:** brakuje scalonego modelu pokoi i kondygnacji, trwałych przypisań pokój–kondygnacja oraz powiązań powierzchnia–pokój–skan. To zależność wspólnego resolvera pokój/kondygnacja/dom, kontroli przecięć we wspólnych współrzędnych i powiązania wyników z wysokościami. `floorsForPlanning(_:)` w `FloorVariantPlanning.swift` rozwiązuje wyłącznie listę UUID podłóg; korzystają z niego obliczenia pojedynczej podłogi, zaznaczenia i wariantu. Odrzuca pustą listę, duplikaty i brakujące powierzchnie, ale nie rozwiązuje zakresów mapy. Przyciski w `WorkspaceView.swift` wybierają `selectedFloorIDs` i grupują podłogi po etykiecie `storey`; nie zastępuje to relacji kondygnacja–pokój. `ScanTransform` nie ma trwałego powiązania z podłogą. Pokój bez podłogi nie ma niezależnego zakresu bazowego. Obliczenia wielu podłóg nie stanowią więc implementacji planowania zakresów domu; tej blokady nie usuwają testy wyboru UUID.
- **Sprawdzalny test gotowości (warunek, nie wynik istniejących testów):** zapisz i ponownie otwórz dom z dwiema kondygnacjami oraz co najmniej jednym pokojem bez podłogi. Bez odczytu `floors`/`floorVariants` wylicz trwałe identyfikatory wszystkich pokoi i ich jednoznacznych rodziców. Wybór pokoju, kondygnacji i domu musi dawać właściwe zbiory oraz zgodny podgląd źródeł, również po zmianie wariantu podłogi. Sprawdź znany punkt i wysokość na obu kondygnacjach względem pomiarów; korekta skanu i ponowne otwarcie muszą zachować położenie powiązanych obiektów oraz oryginalne źródła. Dziś test zatrzymuje się na braku rejestru kondygnacji, relacji pokoi i powiązania obiektów z mapą. Dalsze zadania mebli wymagające tych zakresów pozostają zablokowane; test zapisu kolekcji mebli nie usuwa blokady.
- **Łączenie i rozdzielanie — wymagania:** docelowo osobne pokoje, kondygnacje, przejście przez dom i importowane USDZ porządkujemy na jednej mapie. Podgląd i ręczne przesunięcie/obrót/wysokość już istnieją; zgrupowanie nie wyrównuje automatycznie sesji ani nie usuwa zdublowanych ścian. Wydzielanie `ModelPart` wybiera węzły bez zmiany ich położenia; nie jest cięciem geometrii ani modelem kondygnacji. USDZ bez semantyki pokoi wymaga zaznaczenia lub cięcia. Podział i łączenie podłóg 2D nie realizuje tych operacji 3D. Przejście przez dom pozostaje scenariuszem docelowym z ograniczeniami śledzenia, rozmiaru sceny i kondygnacji.
- **Niedestrukcyjność i kolejność:** zachować źródła i podgląd → ustawić i połączyć modele → wydzielić części i eksportować. Odłączenie części i cofanie nie mogą niszczyć oryginałów; eksport części lub całości do USDZ pozostaje osobnym wynikiem, nie zamiennikiem źródeł. Warianty USDZ wymagają weryfikacji na rzeczywistych plikach; importer podłóg nie jest ogólnym edytorem USDZ.

### Instalacje — jeden prosty mechanizm na później

Instalację przedstawiamy jako linie lub łamane o zadanej średnicy w milimetrach, na wspólnej mapie domu. Instalacje rozróżniamy nazwą i kolorem: n kolorów może oznaczać n instalacji. Dodanie kolejnej instalacji to kolejne dane, nie osobny silnik ani moduł branżowy. Jeden edytor przebiegu i średnicy ma obsługiwać wszystkie te warstwy.

To model do rozmieszczania i dokumentowania tras, nie deklaracja obliczeń hydraulicznych, elektrycznych czy wentylacyjnych. Na tym etapie nie budujemy takich obliczeń ani katalogów branżowych.

To warstwy jednego projektu domu, powiązane ze wspólną przestrzenią, nie osobne, niepowiązane plany. Stan istniejący i wykonany powinien być odróżnialny od zamierzeń. Skan jest źródłem geometrii — nie oznacza automatycznego rozpoznania ukrytych instalacji.

**Stan obecny:** aplikacja natywna importuje istniejące skany RoomPlan USDZ albo przyjmuje wymiary prostokątnego pokoju, zapisuje projekty lokalnie i planuje podłogi. Na iOS dodano przebieg wielu pokoi w jednej sesji Apple RoomPlan, składanie przez `StructureBuilder` oraz zapis modeli źródłowych i wyniku. Ta ścieżka jest sprawdzona kompilacją i testami logiki/zapisu, nie skanem na fizycznym urządzeniu; nie wyprowadza jeszcze podłóg ani nie składa osobnych sesji lub importowanych USDZ w mapę domu. Nie ma jeszcze edytorów pozostałych instalacji. Powyższy kierunek nie jest listą już dostarczonych funkcji.

Obecne drzewo `Workspace → Project → Scan + Floor` opisuje aktualną implementację, nie kolejność rozwoju produktu. `Project` jest miejscem dalszego rozwoju mapy domu; przyszłe instalacje nie powinny być modelowane jako rodzaje podłogi. Nie dodajemy teraz pustych modułów ani nowego schematu danych na zapas.

## Planowanie podłóg — istniejąca implementacja

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

Host Python udostępnia pokoje wyłącznie właścicielowi wskazanemu przez sesję adaptera (`PlatformUser.user_id`). Gość jest przekierowywany do logowania bez odczytu i zapisu pokojów. Historyczne dane `local` pozostają w magazynie i nie są przypisywane kontom. Host wymaga konfiguracji adapterów tożsamości oraz mapowania zweryfikowanej sesji przez `current_user`; bez niego trasy pokojów odmawiają dostępu.

Użytkownik podaje obrys, kąt i podziałkę (np. pół kafelki, pół panele) albo wgrywa skan RoomPlan (USDZ). Serwer liczy dylatację, siatkę, docinki, odcięcia na progach (listwa), BOM i kolejność.

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
