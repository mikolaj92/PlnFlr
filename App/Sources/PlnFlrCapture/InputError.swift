import Foundation

enum PlanningScopeError: LocalizedError {
    case unselected, empty, missing, accessDenied

    var errorDescription: String? {
        switch self {
        case .unselected: "Wybierz pokój, kondygnację lub dom. Zaznaczenie geometrii nie zmienia zakresu."
        case .empty: "Zakres nie zawiera powierzchni. Sprawdź przypisania pokoi."
        case .missing: "Powierzchnia zakresu już nie istnieje. Wybierz zakres ponownie."
        case .accessDenied: "Obliczenie wszystkich powierzchni wariantu wymaga PlnFlr Pro."
        }
    }
}

enum ManualRoomError: Error {
    case invalidDimensions
}

enum MaterialInputError: LocalizedError, Equatable {
    case invalid
    case tooManyPieces
    var errorDescription: String? {
        switch self {
        case .invalid: "Sprawdź materiał: długość i szerokość 0,05–5 m, dylatacja 0–100 mm, fuga 0–20 mm, paczka 1–1000 sztuk."
        case .tooManyPieces: "Plan przekracza lokalny limit 20 000 elementów. Podziel powierzchnię lub wybierz większy materiał."
        }
    }
}
