import ComposableArchitecture2
import SwiftUI

struct WelcomeView: View {
    @Bindable var store: StoreOf<Workspace>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "square.grid.3x3.square").font(.system(size: 48)).foregroundStyle(.orange)
                Text("Zaplanuj swoją podłogę").font(.largeTitle.bold())
                Text("Od obrysu pokoju do układu desek, docinek i liczby paczek.").foregroundStyle(.secondary)
                Label("1. Wgraj skan RoomPlan USDZ lub podaj wymiary", systemImage: "house")
                Label("2. Wybierz pokój i materiał", systemImage: "square.stack")
                Label("3. Sprawdź cały plan i listę zakupów", systemImage: "checkmark.circle")
                Button("Podaj wymiary pokoju", systemImage: "ruler") { $store.isAddingRoom.wrappedValue = true }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("startManualRoom")
                Button("Importuj skan USDZ", systemImage: "square.and.arrow.down") { $store.isImporting.wrappedValue = true }
                    .buttonStyle(.bordered)
                Text("Pierwszy zaplanowany pokój gratis. Kolejne pokoje odblokowuje jednorazowe Pro. Import i podgląd skanu są bezpłatne.")
                    .font(.footnote).foregroundStyle(.secondary)
                Label("Bez konta. Projekty zapisujemy na tym urządzeniu.", systemImage: "lock.shield")
                    .font(.footnote)
                if let message = store.error {
                    Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

struct ManualRoomView: View {
    @Bindable var store: StoreOf<Workspace>

    var body: some View {
        NavigationStack {
            Form {
                Section("Pokój prostokątny") {
                    TextField("Nazwa", text: $store.manualName).accessibilityIdentifier("manualName")
                    TextField("Szerokość (m)", text: $store.manualWidthM).accessibilityIdentifier("manualWidth")
                    TextField("Długość (m)", text: $store.manualHeightM).accessibilityIdentifier("manualHeight")
                }
                Section {
                    Text("Możesz użyć przecinka lub kropki, np. 4,25. Dla nieregularnego obrysu zaimportuj skan RoomPlan USDZ.")
                    if let message = store.manualRoomError {
                        Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Dodaj pokój")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { $store.isAddingRoom.wrappedValue = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dodaj") { store.send(.addRoomButtonTapped) }
                        .accessibilityIdentifier("confirmManualRoom")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 340)
        #endif
    }
}

struct ProView: View {
    @Bindable var store: StoreOf<Workspace>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("PlnFlr Pro", systemImage: "sparkles").font(.largeTitle.bold())
                    Text(store.hasPro ? "Pro jest aktywne" : "Zaplanuj wszystkie pokoje").font(.title2)
                    Label("Nieograniczona liczba planowanych pokoi", systemImage: "house.fill")
                    Label("Jednorazowy zakup, bez abonamentu", systemImage: "checkmark.seal")
                    Text("Zmiany materiału, ponowne obliczenia i techniczne podziały pierwszego pokoju pozostają bezpłatne. Projekty nie są usuwane po utracie dostępu do Pro.")
                    if !store.hasPro {
                        if let product = store.proProduct {
                            Button("Kup Pro — \(product.displayPrice)") { store.send(.buyProButtonTapped) }
                                .buttonStyle(.borderedProminent)
                                .disabled(store.isPurchasing)
                                .accessibilityIdentifier("buyPro")
                        } else {
                            Text("Produkt jest chwilowo niedostępny. Przy pracy lokalnej uruchom schemat PlnFlr z konfiguracją StoreKit.")
                                .foregroundStyle(.secondary)
                            Button("Wczytaj ofertę ponownie") { store.send(.reloadProductButtonTapped) }
                        }
                    }
                    Button("Przywróć zakupy") { store.send(.restorePurchasesButtonTapped) }
                        .disabled(store.isPurchasing)
                        .accessibilityIdentifier("restorePurchases")
                    if store.isPurchasing { ProgressView("Kontakt z Apple…") }
                    if let message = store.purchaseMessage {
                        Text(message).accessibilityIdentifier("purchaseMessage")
                    }
                    Text("Zakup jest przypisany do konta Apple używanego w App Store. Nie odblokowuje wersji webowej. Nie potrzebujesz konta PlnFlr.")
                        .font(.footnote).foregroundStyle(.secondary)
                    #if DEBUG
                    Text("W schemacie lokalnym zakupy są symulowane — bez prawdziwej opłaty. Cena w pliku StoreKit jest ceną testową.")
                        .font(.footnote).foregroundStyle(.secondary)
                    #endif
                }
                .padding(24)
                .frame(maxWidth: 560, alignment: .leading)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { $store.isPaywallPresented.wrappedValue = false }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 540)
        #endif
    }
}
