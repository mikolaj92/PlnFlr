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

### Skany — łączenie i rozdzielanie modeli

Docelowo sposób zebrania danych nie narzuca podziału domu: można skanować pokoje osobno, całą kondygnację albo przejść przez cały dom, a potem uporządkować model. Dotyczy to także importowanych modeli USDZ, nie tylko skanów wykonanych w aplikacji.

- **Łączenie:** zestawienie kilku modeli w jedną mapę, z zachowaniem części źródłowych. Osobne sesje mogą mieć różne początki układu współrzędnych; potrzebne są podgląd oraz korekta przesunięcia, obrotu i wysokości. Samo zgrupowanie nie oznacza automatycznego dopasowania ani usunięcia zdublowanych ścian.
- **Rozdzielanie:** wydzielenie z większego modelu pomieszczeń, kondygnacji lub wskazanych fragmentów, bez zmiany ich położenia we wspólnej przestrzeni. Gdy źródło nie ma takich części, potrzebne jest zaznaczenie lub cięcie geometrii — nie zakładamy, że każdy USDZ zawiera semantykę pokoi.
- **Niedestrukcyjność:** oryginalne pliki pozostają zachowane; można odłączyć część lub cofnąć operację. Eksport wybranej części albo całości do USDZ jest osobnym wynikiem pracy, nie zamiennikiem źródeł projektu.

To wymagania bieżącego etapu skanów, jeszcze nie dostarczone funkcje. Istniejący podział i łączenie powierzchni podłogowych 2D nie realizuje operacji na pełnych modelach 3D. Przejście przez cały dom jest scenariuszem docelowym, nie gwarancją nieograniczonej sesji RoomPlan; trzeba uwzględnić ograniczenia śledzenia, rozmiaru sceny i kondygnacji.

Kolejność: zachowanie oryginalnych USDZ i podgląd 3D → ustawianie i łączenie modeli → wydzielanie części i eksport. Obsługę wariantów USDZ weryfikujemy na rzeczywistych plikach; obecny importer podłóg nie jest ogólnym edytorem USDZ.

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
