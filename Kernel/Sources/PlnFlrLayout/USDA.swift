import Foundation

struct UsdaMesh {
    var name: String
    var category: String
    var points: [(Double, Double, Double)]
    var counts: [Int]
    var indices: [Int]
    var matrix: [[Double]]
}

func parseUsdaMesh(_ text: String, name: String) throws -> UsdaMesh {
    guard let matrix = parseMatrix(text), let points = parsePoints(text) else {
        throw ScanError.missingMesh(name)
    }
    let counts = ints(between: "int[] faceVertexCounts = [", and: "]", in: text)
    let indices = ints(between: "int[] faceVertexIndices = [", and: "]", in: text)
    let category = stringField("Category", in: text) ?? name
    return UsdaMesh(
        name: name,
        category: category,
        points: points,
        counts: counts,
        indices: indices,
        matrix: matrix
    )
}

func transformPoint(
    _ point: (Double, Double, Double),
    matrix: [[Double]]
) -> (Double, Double, Double) {
    let x = point.0, y = point.1, z = point.2
    return (
        x * matrix[0][0] + y * matrix[1][0] + z * matrix[2][0] + matrix[3][0],
        x * matrix[0][1] + y * matrix[1][1] + z * matrix[2][1] + matrix[3][1],
        x * matrix[0][2] + y * matrix[1][2] + z * matrix[2][2] + matrix[3][2]
    )
}

private func parseMatrix(_ text: String) -> [[Double]]? {
    guard let range = text.range(of: "matrix4d xformOp:transform = ") else { return nil }
    let rest = text[range.upperBound...]
    guard let open = rest.firstIndex(of: "(") else { return nil }
    var depth = 0
    var end = open
    for idx in rest[open...].indices {
        let ch = rest[idx]
        if ch == "(" { depth += 1 }
        if ch == ")" {
            depth -= 1
            if depth == 0 {
                end = idx
                break
            }
        }
    }
    let body = rest[rest.index(after: open)..<end]
    let rows = triples(String(body))
    guard rows.count == 4 else { return nil }
    return rows
}

private func parsePoints(_ text: String) -> [(Double, Double, Double)]? {
    guard let inner = slice(text, after: "point3f[] points = [", until: "]") else { return nil }
    let rows = triples(inner)
    return rows.map { ($0[0], $0[1], $0[2]) }
}

private func triples(_ raw: String) -> [[Double]] {
    var rows: [[Double]] = []
    var current = ""
    var depth = 0
    for ch in raw {
        if ch == "(" {
            depth += 1
            current = ""
        } else if ch == ")" {
            if depth == 1 {
                let nums = current.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                if nums.count >= 3 { rows.append(nums) }
            }
            depth -= 1
        } else if depth == 1 {
            current.append(ch)
        }
    }
    return rows
}

private func ints(between start: String, and end: String, in text: String) -> [Int] {
    guard let inner = slice(text, after: start, until: end) else { return [] }
    let pattern = try! NSRegularExpression(pattern: #"-?\d+"#)
    let ns = inner as NSString
    return pattern.matches(in: inner, range: NSRange(location: 0, length: ns.length)).compactMap {
        Int(ns.substring(with: $0.range))
    }
}

private func stringField(_ key: String, in text: String) -> String? {
    let pattern = try! NSRegularExpression(pattern: #"string \#(key) = \"([^\"]+)\""#)
    let ns = text as NSString
    guard let match = pattern.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
          match.numberOfRanges > 1
    else { return nil }
    return ns.substring(with: match.range(at: 1))
}

private func slice(_ text: String, after start: String, until end: String) -> String? {
    guard let range = text.range(of: start) else { return nil }
    let rest = text[range.upperBound...]
    guard let close = rest.range(of: end) else { return nil }
    return String(rest[..<close.lowerBound])
}

public enum ScanError: Error, Equatable, LocalizedError {
    case notZip
    case notRoomPlan
    case missingFloor
    case missingMesh(String)
    case noFloorPlane
    case noOutline
    case brokenOutline
    case noPlan(String)
    case tooLarge

    public var errorDescription: String? {
        switch self {
        case .notZip: "to nie jest RoomPlan USDZ"
        case .notRoomPlan: "USDZ nie jest skanem RoomPlan (brak Scan.usda)"
        case .missingFloor: "RoomPlan: brak podłogi"
        case .missingMesh(let name): "USDZ nie ma siatki \(name)"
        case .noFloorPlane: "RoomPlan: podłoga nie ma płaszczyzny"
        case .noOutline: "RoomPlan: nie da się odczytać obrysu podłogi"
        case .brokenOutline: "RoomPlan: obrys podłogi jest uszkodzony"
        case .noPlan(let name): "RoomPlan: \(name) nie ma rzutu na podłogę"
        case .tooLarge: "Skan jest za duży."
        }
    }
}
