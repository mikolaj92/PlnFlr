import Foundation
import PlnFlrLayout
import Vapor

struct LayoutForm: Content {
    var shape: String = "rect"
    var kind: String = "plank"
    var kind_b: String = "tile"
    var width_m: String = "4.000"
    var height_m: String = "3.000"
    var l_span_x_m: String = "6.000"
    var l_span_y_m: String = "4.000"
    var l_cutout_x_m: String = "2.500"
    var l_cutout_y_m: String = "2.000"
    var vertices: String = ""
    var hole_rectangles: String = ""
    var hole_vertices: String = ""
    var door_rectangles: String = ""
    var door_vertices: String = ""
    var window_segments: String = ""
    var plank_length_m: String = "1.383"
    var plank_width_m: String = "0.156"
    var boards_per_pack: String = "8"
    var tile_length_m: String = "0.600"
    var tile_width_m: String = "0.600"
    var grout_mm: String = "3"
    var expansion_mm: String = ""
    var direction: String = "along_long"
    var stagger: String = "third"
    var angle_deg: String = "0"
    var split: String = "none"
    var split_at_m: String = ""

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shape = try c.decodeIfPresent(String.self, forKey: .shape) ?? "rect"
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "plank"
        kind_b = try c.decodeIfPresent(String.self, forKey: .kind_b) ?? "tile"
        width_m = try c.decodeIfPresent(String.self, forKey: .width_m) ?? "4.000"
        height_m = try c.decodeIfPresent(String.self, forKey: .height_m) ?? "3.000"
        l_span_x_m = try c.decodeIfPresent(String.self, forKey: .l_span_x_m) ?? "6.000"
        l_span_y_m = try c.decodeIfPresent(String.self, forKey: .l_span_y_m) ?? "4.000"
        l_cutout_x_m = try c.decodeIfPresent(String.self, forKey: .l_cutout_x_m) ?? "2.500"
        l_cutout_y_m = try c.decodeIfPresent(String.self, forKey: .l_cutout_y_m) ?? "2.000"
        vertices = try c.decodeIfPresent(String.self, forKey: .vertices) ?? ""
        hole_rectangles = try c.decodeIfPresent(String.self, forKey: .hole_rectangles) ?? ""
        hole_vertices = try c.decodeIfPresent(String.self, forKey: .hole_vertices) ?? ""
        door_rectangles = try c.decodeIfPresent(String.self, forKey: .door_rectangles) ?? ""
        door_vertices = try c.decodeIfPresent(String.self, forKey: .door_vertices) ?? ""
        window_segments = try c.decodeIfPresent(String.self, forKey: .window_segments) ?? ""
        plank_length_m = try c.decodeIfPresent(String.self, forKey: .plank_length_m) ?? "1.383"
        plank_width_m = try c.decodeIfPresent(String.self, forKey: .plank_width_m) ?? "0.156"
        boards_per_pack = try c.decodeIfPresent(String.self, forKey: .boards_per_pack) ?? "8"
        tile_length_m = try c.decodeIfPresent(String.self, forKey: .tile_length_m) ?? "0.600"
        tile_width_m = try c.decodeIfPresent(String.self, forKey: .tile_width_m) ?? "0.600"
        grout_mm = try c.decodeIfPresent(String.self, forKey: .grout_mm) ?? "3"
        expansion_mm = try c.decodeIfPresent(String.self, forKey: .expansion_mm) ?? ""
        direction = try c.decodeIfPresent(String.self, forKey: .direction) ?? "along_long"
        stagger = try c.decodeIfPresent(String.self, forKey: .stagger) ?? "third"
        angle_deg = try c.decodeIfPresent(String.self, forKey: .angle_deg) ?? "0"
        split = try c.decodeIfPresent(String.self, forKey: .split) ?? "none"
        split_at_m = try c.decodeIfPresent(String.self, forKey: .split_at_m) ?? ""
    }

    func asDict() -> [String: String] {
        [
            "shape": shape, "kind": kind, "kind_b": kind_b,
            "width_m": width_m, "height_m": height_m,
            "l_span_x_m": l_span_x_m, "l_span_y_m": l_span_y_m,
            "l_cutout_x_m": l_cutout_x_m, "l_cutout_y_m": l_cutout_y_m,
            "vertices": vertices, "hole_rectangles": hole_rectangles,
            "hole_vertices": hole_vertices, "door_rectangles": door_rectangles,
            "door_vertices": door_vertices, "window_segments": window_segments,
            "plank_length_m": plank_length_m, "plank_width_m": plank_width_m,
            "boards_per_pack": boards_per_pack, "tile_length_m": tile_length_m,
            "tile_width_m": tile_width_m, "grout_mm": grout_mm,
            "expansion_mm": expansion_mm, "direction": direction,
            "stagger": stagger, "angle_deg": angle_deg,
            "split": split, "split_at_m": split_at_m,
        ]
    }
}

func layoutFromForm(_ form: LayoutForm) throws -> LayoutPlan {
    var room = try roomFromForm(form)
    let doorRings = try rectangularHoles(form.door_rectangles) + polygonalHoles(form.door_vertices)
    if !doorRings.isEmpty {
        room = Room(room.outer, holes: room.holes + doorRings)
    }
    let windows = try windowOpenings(form.window_segments)
    let rules = try rulesFromForm(form)
    let plan: LayoutPlan
    if form.split == "none" {
        let label = form.kind == "tile" ? "Płytki" : "Panele"
        plan = try layoutFloor(room, zones: [try zone(form, kind: form.kind, label: label)], rules: rules, windows: windows)
    } else {
        let splitAt = form.split_at_m.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : try metresToMm(form.split_at_m)
        plan = try layoutFloor(
            room,
            zones: [
                try zone(form, kind: form.kind, label: "Strefa A"),
                try zone(form, kind: form.kind_b, label: "Strefa B"),
            ],
            rules: rules,
            splitAxis: form.split == "x" ? .x : .y,
            splitAtMm: splitAt,
            windows: windows
        )
    }
    if doorRings.isEmpty { return plan }
    var copy = plan
    copy.thresholds = doorRings.map(thresholdFromRing)
    return copy
}

func roomFromForm(_ form: LayoutForm) throws -> Room {
    let outer: Ring
    switch form.shape {
    case "rect":
        outer = try rectangle(widthMm: try metresToMm(form.width_m), heightMm: try metresToMm(form.height_m)).outer
    case "l":
        outer = try lShape(
            spanXMm: try metresToMm(form.l_span_x_m),
            spanYMm: try metresToMm(form.l_span_y_m),
            cutoutXMm: try metresToMm(form.l_cutout_x_m),
            cutoutYMm: try metresToMm(form.l_cutout_y_m)
        ).outer
    default:
        outer = try parseVertices(form.vertices)
    }
    let holes = try rectangularHoles(form.hole_rectangles) + polygonalHoles(form.hole_vertices)
    return Room(outer, holes: holes)
}

func parseVertices(_ raw: String) throws -> Ring {
    var points: [Vertex] = []
    for line in raw.split(whereSeparator: \.isNewline) {
        let text = line.trimmingCharacters(in: .whitespaces)
        if text.isEmpty { continue }
        let parts = text.replacingOccurrences(of: ";", with: ",").split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
        guard parts.count == 2 else { throw FormError.vertex }
        points.append(Vertex(try metresToMmCoord(parts[0]), try metresToMmCoord(parts[1])))
    }
    return try Ring(points)
}

private func rectangularHoles(_ raw: String) throws -> [Ring] {
    var holes: [Ring] = []
    for line in raw.split(whereSeparator: \.isNewline) {
        let text = line.trimmingCharacters(in: .whitespaces)
        if text.isEmpty { continue }
        let parts = text.replacingOccurrences(of: ";", with: ",").split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard parts.count == 4, parts.allSatisfy({ !$0.isEmpty }) else { throw FormError.holeRect }
        let x = try metresToMmCoord(parts[0])
        let y = try metresToMmCoord(parts[1])
        let width = try metresToMm(parts[2])
        let height = try metresToMm(parts[3])
        holes.append(try Ring([
            Vertex(x, y), Vertex(x + width, y), Vertex(x + width, y + height), Vertex(x, y + height),
        ]))
    }
    return holes
}

private func polygonalHoles(_ raw: String) throws -> [Ring] {
    var holes: [Ring] = []
    var lines: [String] = []
    for line in raw.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init) + [""] {
        if !line.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append(line)
        } else if !lines.isEmpty {
            holes.append(try parseVertices(lines.joined(separator: "\n")))
            lines = []
        }
    }
    return holes
}

private func windowOpenings(_ raw: String) throws -> [Opening] {
    var openings: [Opening] = []
    for line in raw.split(whereSeparator: \.isNewline) {
        let text = line.trimmingCharacters(in: .whitespaces)
        if text.isEmpty { continue }
        let parts = text.replacingOccurrences(of: ";", with: ",").split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard parts.count == 4, parts.allSatisfy({ !$0.isEmpty }) else { throw FormError.window }
        openings.append(
            Opening(
                label: "okno",
                start: Vertex(try metresToMmCoord(parts[0]), try metresToMmCoord(parts[1])),
                end: Vertex(try metresToMmCoord(parts[2]), try metresToMmCoord(parts[3]))
            )
        )
    }
    return openings
}

private func rulesFromForm(_ form: LayoutForm) throws -> LayoutRules {
    LayoutRules(
        expansionMm: try nonNegativeInt(form.expansion_mm, field: "dylatacja"),
        stagger: form.stagger == "half" ? .half : .third,
        direction: direction(form.direction),
        angleDeg: angleDeg(form.angle_deg)
    )
}

private func direction(_ raw: String) -> LayDirection {
    switch raw {
    case "along_short": .alongShort
    case "into_window": .intoWindow
    default: .alongLong
    }
}

private func angleDeg(_ raw: String) -> Int {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return (Int(text.isEmpty ? "0" : text) ?? 0) % 360
}

private func zone(_ form: LayoutForm, kind: String, label: String) throws -> Zone {
    if kind == "tile" {
        return Zone(kind: .tile, tile: try tileFromForm(form), label: label)
    }
    return Zone(kind: .plank, plank: try plankFromForm(form), label: label)
}

private func plankFromForm(_ form: LayoutForm) throws -> PlankSpec {
    PlankSpec(
        lengthMm: try metresToMm(form.plank_length_m),
        widthMm: try metresToMm(form.plank_width_m),
        boardsPerPack: try positiveInt(form.boards_per_pack, field: "sztuk w paczce")
    )
}

private func tileFromForm(_ form: LayoutForm) throws -> TileSpec {
    TileSpec(
        lengthMm: try metresToMm(form.tile_length_m),
        widthMm: try metresToMm(form.tile_width_m),
        groutMm: try positiveInt(form.grout_mm, field: "fuga") ?? 0
    )
}

private func thresholdFromRing(_ ring: Ring) -> Threshold {
    let verts = ring.vertices
    let edges = verts.indices.map { index -> Int in
        let nxt = verts[(index + 1) % verts.count]
        let dx = Double(nxt.xMm - verts[index].xMm)
        let dy = Double(nxt.yMm - verts[index].yMm)
        return Int((dx * dx + dy * dy).squareRoot().rounded())
    }
    return Threshold(
        label: "listwa progowa",
        lengthMm: edges.max() ?? 0,
        widthMm: edges.min() ?? 0,
        geometry: ring
    )
}

private func positiveInt(_ raw: String, field: String) throws -> Int? {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.isEmpty { return nil }
    guard let value = Int(text) else { throw FormError.int(field) }
    if value <= 0 { throw FormError.positive(field) }
    return value
}

private func nonNegativeInt(_ raw: String, field: String) throws -> Int? {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.isEmpty { return nil }
    guard let value = Int(text) else { throw FormError.int(field) }
    if value < 0 { throw FormError.nonNegative(field) }
    return value
}

enum FormError: Error, LocalizedError {
    case vertex, holeRect, window, int(String), positive(String), nonNegative(String)
    var errorDescription: String? {
        switch self {
        case .vertex: "każdy wierzchołek to x,y w metrach"
        case .holeRect: "każdy prostokątny otwór to x,y,szerokość,wysokość w metrach"
        case .window: "każde okno to x1,y1,x2,y2 w metrach"
        case .int(let field): "\(field) musi być liczbą całkowitą"
        case .positive(let field): "\(field) musi być dodatnie"
        case .nonNegative(let field): "\(field) nie może być ujemne"
        }
    }
}
