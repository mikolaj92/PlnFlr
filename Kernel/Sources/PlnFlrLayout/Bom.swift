import Foundation

func wastePct(areaBoughtMm2: Int, areaNetMm2: Int) -> String {
    guard areaNetMm2 > 0 else { return "0.0" }
    var ratio = Decimal(areaBoughtMm2 - areaNetMm2) * 100 / Decimal(areaNetMm2)
    var rounded = Decimal()
    NSDecimalRound(&rounded, &ratio, 1, .plain)
    return "\(rounded)"
}

func makeBom(
    pieces: Int,
    fullBoards: Int,
    boardsPerPack: Int?,
    areaNetMm2: Int,
    boardAreaMm2: Int,
    label: String = "",
    kind: ZoneKind = .plank
) -> BillOfMaterials {
    let bought = fullBoards * boardAreaMm2
    var packs: Int?
    if let pack = boardsPerPack, pack > 0 {
        packs = (fullBoards + pack - 1) / pack
    }
    return BillOfMaterials(
        areaBoughtMm2: bought,
        areaNetMm2: areaNetMm2,
        fullBoards: fullBoards,
        kind: kind,
        label: label,
        packs: packs,
        pieces: pieces,
        wastePct: wastePct(areaBoughtMm2: bought, areaNetMm2: areaNetMm2)
    )
}
