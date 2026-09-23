# PlnFlr — praca lokalna

Bez kont PlnFlr, bez backendu kont, bez TestFlight. Projekty zapisują się na urządzeniu. Uprawnienie Pro pochodzi wyłącznie ze zweryfikowanych transakcji StoreKit 2, nigdy z JSON projektu.

## Uruchomienie

Otwórz **`App/PlnFlrWorkspace.xcworkspace`**, wybierz schemat **PlnFlr** i **My Mac**. Schemat Run ma podpięty `PlnFlr.storekit`: jeden produkt non-consumable `it.patryk.plnflr.pro`. Cena 49,99 jest wyłącznie testowa, nie jest decyzją cenową ani ofertą App Store Connect.

Do budowania nie trzeba konta Apple Developer na macOS ani dla iOS Simulator. Instalacja na fizycznym iPhonie/iPadzie wymaga skonfigurowania podpisywania w Xcode. Minimum: iOS/macOS 26.4. Aktualny host ma Xcode 27 beta z SDK 27; minimalne wersje pozostają 26.4.

```sh
# Z katalogu repo
swift run --package-path App PlnFlrApp
# SPM uruchamia UI bez podpiętej konfiguracji zakupów; do StoreKit użyj schematu Xcode.

xcodebuild -workspace App/PlnFlrWorkspace.xcworkspace -scheme PlnFlr \
  -destination 'platform=macOS' -derivedDataPath App/.derivedData \
  -clonedSourcePackagesDirPath App/.build CODE_SIGN_IDENTITY=- build
open App/.derivedData/Build/Products/Debug/PlnFlr.app
```

Zwykłe otwarcie `.app` poza Xcode również nie włącza lokalnego sklepu.

## Przepływ

1. Podaj wymiary prostokątnego pokoju albo zaimportuj USDZ RoomPlan (do 50 MB).
2. Wybierz pokój; ustaw deski/panele lub płytki, wymiary, paczkę, dylatację i fugę.
3. Wybierz **Ułóż podłogę**. Zobacz mapę elementów, paczki, odpad, ostrzeżenia i kolejność układania.
4. Pierwsze udane obliczenie przypisuje bezpłatny dostęp do tego pokoju. Import wielu pomieszczeń nie jest blokowany. Błędne obliczenie nie wykorzystuje darmowego pokoju.
5. Kolejne pokoje pokazują Pro. Ponowne obliczenia i techniczne podziały bezpłatnego pokoju zachowują dostęp. Łączenie odrębnych pokoi tworzy nową powierzchnię, nie przenosi darmowego uprawnienia na dodatkowe pokoje.
6. Po ponownym uruchomieniu wracają projekty, skany, powierzchnie, ustawienia i wybór darmowego pokoju. Podgląd jest wynikiem obliczeń: użyj ponownie **Ułóż podłogę**.

Lokalny limit to 20 000 oszacowanych elementów na plan; bardzo duże siatki są odrzucane przed alokacją. Ręczny obrys jest obecnie prostokątny. To import istniejących skanów, nie nowy interfejs skanowania kamerą.

## Dane i błędy zapisu

`Application Support/PlnFlr/workspace.json` (w kontenerze aplikacji dla sandboxowanej `.app`; SPM używa zwykłego katalogu użytkownika). Zapis atomowy po zmianach danych projektu, także przez bindings. Błąd zapisu jest widoczny z opcją ponowienia. Nieczytelny/nieobsługiwany plik blokuje zapis, aby nie nadpisać go pustym projektem. Nie ma automatycznego kasowania ani resetu danych. W tej wersji nie ma iCloud ani eksportu/odzyskiwania kopii z UI. Plik nie jest zaszyfrowany.

Darmowy pokój jest lokalnym stanem produktu, nie odpornym na reinstalację licznikiem. Bez własnego konta/serwera nie obiecujemy limitu „raz na osobę”. Zakup Pro można odzyskać przez App Store; nie odzyskuje to samych lokalnych projektów.

## Testy

```sh
swift test --package-path App
swift test --package-path Kernel
swift test --package-path Web

# Renderowanie widoków i regresja otworów w dark mode
xcodebuild -workspace App/PlnFlrWorkspace.xcworkspace -scheme PlnFlr \
  -destination 'platform=macOS' -derivedDataPath App/.derivedData \
  -clonedSourcePackagesDirPath App/.build CODE_SIGN_IDENTITY=- \
  -only-testing:PlnFlrLocalTests/RenderingTests test

# Prawdziwy adapter StoreKit + SKTestSession (lokalny zakup, restore, refund)
xcodebuild -workspace App/PlnFlrWorkspace.xcworkspace -scheme PlnFlr \
  -destination 'platform=macOS' -derivedDataPath App/.derivedData \
  -clonedSourcePackagesDirPath App/.build CODE_SIGN_IDENTITY=- \
  -only-testing:PlnFlrLocalTests/StoreKitLocalTests test
```

**Znany blocker tego hosta:** test integracyjny StoreKit nie przechodzi. `storekitagent` odrzuca zapis konfiguracji: `it.patryk.plnflr is not entitled for OctaneSaveConfigurationRequest` / `SKInternalErrorDomain Code=3`; `Product.products` zwraca pustą ofertę. Na hoście nie ma tożsamości podpisujących Apple Development. Nie obchodzimy tego prywatnymi entitlementami ani fikcyjnym odblokowaniem Pro. Test pozostaje czerwony, nie jest skipowany. Testy jednostkowe ścieżek sukces/anulowanie/pending/restore/revocation przechodzą niezależnie od StoreKit hosta. Potrzebna dalsza weryfikacja uruchomienia sklepu przez Xcode / prawidłowo skonfigurowane środowisko Apple.

Brak zainstalowanych runtime'ów iOS Simulator na hoście: kompilacja dla iOS Simulator jest sprawdzona, uruchomienie na iPhonie/iPadzie jeszcze nie. Renderowanie w testach jest offscreen; nie zastępuje interaktywnego QA i niektóre systemowe kontrolki mogą nie być widoczne w bitmapie. PNG trafiają do `/tmp/plnflr-local-previews` i załączników xcresult.

## Projekt Xcode

Moduły i zależności definiują manifesty SPM. Obecne pliki projektu Xcode i schemat służą do lokalnego uruchamiania aplikacji i testów platformowych. Nie ma dodatkowego generatora projektu ani zależności od Ruby.

Nie zmieniaj prywatnego URL TCA26 na HTTPS/publiczny fork. Otwieraj workspace, nie sam `Package.swift`, gdy testujesz target aplikacji i zakupy.
