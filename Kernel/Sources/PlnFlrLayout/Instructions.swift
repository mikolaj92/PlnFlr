func instructionsFor(_ pieces: [Piece], gapMm: Int, hasHoles: Bool) -> [String] {
    var byRow: [Int: [Piece]] = [:]
    for piece in pieces {
        byRow[piece.rowIndex, default: []].append(piece)
    }
    var lines = [
        "Dylatacja \(gapMm) mm wokół obrysu" + (hasHoles ? " i przeszkód." : ".")
    ]
    for row in byRow.keys.sorted() {
        let rowPieces = byRow[row]!.sorted { $0.installOrder < $1.installOrder }
        let width = rowPieces[0].widthMm
        let clips = rowPieces.filter { $0.kind == .clip || $0.kind == .rip }.count
        let start = rowPieces[0].lengthMm
        let end = rowPieces[rowPieces.count - 1].lengthMm
        var note = ""
        if clips > 0 { note = " Przytnij do ściany / otworu." }
        lines.append(
            "Rząd \(row + 1) (szer. \(width) mm): start \(start) mm → \(rowPieces.count) szt. → koniec \(end) mm.\(note)"
        )
    }
    return lines
}
