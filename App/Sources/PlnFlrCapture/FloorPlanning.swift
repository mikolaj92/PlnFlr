import Foundation
import PlnFlrLayout

public enum FloorMaterial: String, Codable, Equatable, Sendable {
    case plank
    case tile
}

public enum FloorFinish: String, Codable, Equatable, Sendable {
    case oak
    case walnut

    var previewColors: [String] {
        switch self {
        case .oak: ["#C7995E", "#AD7A45"]
        case .walnut: ["#6E4733", "#543322"]
        }
    }
}

enum FloorSelectionError: LocalizedError {
    case empty
    case duplicate
    case missing

    var errorDescription: String? {
        switch self {
        case .empty: "Wybierz co najmniej jedną powierzchnię do obliczenia."
        case .duplicate: "Zakres zawiera powtórzoną powierzchnię. Wybierz powierzchnie ponownie."
        case .missing: "Wybrana powierzchnia już nie istnieje. Wybierz zakres ponownie."
        }
    }
}

extension Workspace.Floor.State {
    mutating func copyMaterial(from other: Self) {
        material = other.material
        packSize = other.packSize
        groutMm = other.groutMm
        finish = other.finish
        expansionMm = other.expansionMm
        plankLengthM = other.plankLengthM
        plankWidthM = other.plankWidthM
    }

    func makePlan() throws -> LayoutPlan {
        guard let lengthValue = Decimal(string: plankLengthM), lengthValue > 0,
              let widthValue = Decimal(string: plankWidthM), widthValue > 0 else {
            throw MaterialInputError.invalid
        }
        let length = try metresToMm(plankLengthM)
        let width = try metresToMm(plankWidthM)
        guard (50...5000).contains(length), (50...5000).contains(width),
              let gap = Int(expansionMm), (0...100).contains(gap),
              let pack = Int(packSize), (1...1000).contains(pack),
              let grout = Int(groutMm), (0...20).contains(grout) else {
            throw MaterialInputError.invalid
        }
        let bounds = bbox(room)
        let side = Double(max(bounds.maxX - bounds.minX, bounds.maxY - bounds.minY))
        guard side <= 100_000,
              (side / Double(length) + 2) * (side / Double(width) + 2) <= 20_000 else {
            throw MaterialInputError.tooManyPieces
        }
        let zone: Zone = material == .plank
            ? .init(kind: .plank, plank: .init(lengthMm: length, widthMm: width, boardsPerPack: pack))
            : .init(kind: .tile, tile: .init(lengthMm: length, widthMm: width, groutMm: grout, tilesPerPack: pack))
        var plan = try layoutFloor(room,
            zones: [zone],
            rules: .init(expansionMm: gap), windows: windows)
        plan.thresholds = thresholds
        return plan
    }
}
