# SOUL.md — po co jest PlnFlr

**Każdy dom powinien mieć swój wierny, trwały model 3D, który można otworzyć w aplikacji i rozumieć jako mapę rzeczywistego domu.** Nie jednorazowy skan ani rysunek podłogi — wspólną mapę, uzupełnianą i poprawianą przez lata.

## Co ma umożliwić

Właściciel powinien móc zobaczyć dom i wybrać dowolny zakres tej samej mapy: jedno pomieszczenie, kondygnację albo cały dom. Na wybranym obszarze można planować pracę i policzyć jej materiały — na przykład rozłożyć podłogę w jednym pokoju albo policzyć podłogi dla całego domu.

**Zmiany najpierw dzieją się w modelu, zanim wydarzą się w domu.** Użytkownik powinien móc zachować stan obecny, stworzyć wariant planowanej podłogi, obejrzeć ją w kontekście pomieszczenia lub domu, porównać materiały i układy, a następnie dostać rzeczywiste ilości materiału dla wybranego zakresu. Wizualizacja ma być przestrzenna i zrozumiała — w duchu konfiguratora wnętrza, jak IKEA — ale jej wygląd, model geometrii i obliczenia muszą pozostać rozróżnialne. To samo wybrane rozwiązanie, które widać na podglądzie, ma zasilać zestawienie materiałów; obliczenia wynikają z geometrii i parametrów wybranego materiału, a ich dokładność nie może przekraczać dokładności pomiaru źródłowego.

Ta sama mapa 3D ma później pozwolić zmieniać kolory i wykończenie ścian, dokumentować instalacje ukryte w ścianach, a następnie dodawać meble i inne wyposażenie. To kolejne warstwy tego samego domu, nie oddzielne, niepowiązane aplikacje.

Najważniejszy test sensu produktu jest konkretny: **przed wierceniem otworu w ścianie użytkownik wskazuje miejsce i głębokość, a PlnFlr pokazuje udokumentowane instalacje, które mogą się tam znaleźć.** Przebieg rur, przewodów i pozostałych elementów ma być częścią mapy 3D domu, w ich rzeczywistym położeniu i z zachowaną informacją, skąd ta wiedza pochodzi.

## Dokładność i uczciwość

„Nieznane” nie znaczy „bezpieczne”. Skan pokoju może opisać widoczną geometrię, ale nie odkrywa sam z siebie rur ani przewodów ukrytych w ścianie. Instalacje trzeba zarejestrować na podstawie pomiaru, odkrytej trasy, dokumentacji, zdjęć lub innego wskazanego źródła. Mapa musi odróżniać dane potwierdzone od planowanych, przybliżonych i niezweryfikowanych; nie może przedstawiać braku danych jako braku instalacji ani obiecywać bezpieczeństwa wiercenia bez wystarczających informacji.

Wierność jest ważniejsza niż pozorna kompletność. Zachowujemy oryginalne skany i dokumenty, zapisujemy poprawki oraz źródła, a brak pewności pokazujemy jawnie. Użytkownik może korygować mapę, łączyć i rozdzielać modele bez niszczenia źródeł.

## Kierunek produktu

1. Zbudować mapę całego domu: pokoje, kondygnacje i relacje przestrzenne; przyjmować osobne skany i modele USDZ, łączyć je oraz wydzielać części.
2. Pozwalać wybrać pokój, kondygnację lub cały dom jako zakres pracy na jednej mapie.
3. Zmieniać podłogę najpierw w modelu: wizualizować warianty materiału i układu oraz obliczać rzeczywiste ilości na podstawie geometrii i parametrów materiału.
4. Rozszerzać wizualizację o kolory i wykończenia ścian.
5. Dokumentować trasy instalacji w 3D, z ich źródłem i stopniem potwierdzenia; wykorzystać je do sprawdzania kolizji przed wierceniem i innymi pracami.
6. Dodawać meble i pozostałe wyposażenie, zachowując mapę, warianty i udokumentowany stan domu przy remoncie, serwisie i sprzedaży.

To jest kompas produktu, nie deklaracja, że obecna aplikacja już to potrafi. Każdy etap ma być weryfikowany na rzeczywistych skanach i pomiarach. Nie zastępujemy brakujących pomiarów domysłami ani nie nazywamy przybliżonego modelu dokładnym. Ilości materiału są wiarygodne tylko w granicach jakości geometrii, wymiarów produktu i opakowań wprowadzonych do projektu.
