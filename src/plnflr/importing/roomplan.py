"""RoomPlan USDZ → floor polygon, object holes, door thresholds."""

from __future__ import annotations

import io
import math
import zipfile
from collections import defaultdict
from dataclasses import dataclass

from plnflr.domain.models import Ring, Room, Threshold, Vertex
from plnflr.domain.units import metres_to_mm_coord
from plnflr.engine.clip import normalize_ring
from plnflr.importing.usda import UsdaMesh, parse_usda_mesh, transform_point

THRESHOLD_MM = 80
_TOP_Z = 0.02
_ROOM_NAMES = {
    "livingroom": "Salon",
    "bedroom": "Sypialnia",
    "bathroom": "Łazienka",
    "kitchen": "Kuchnia",
    "diningroom": "Jadalnia",
}


@dataclass(frozen=True, slots=True)
class CapturedScan:
    name: str
    room: Room
    thresholds: tuple[Threshold, ...]
    vertices_m: str
    hole_rectangles: str
    door_vertices: str


def room_from_usdz(payload: bytes) -> CapturedScan:
    try:
        archive = zipfile.ZipFile(io.BytesIO(payload))
    except zipfile.BadZipFile as exc:
        raise ValueError("to nie jest RoomPlan USDZ") from exc
    names = archive.namelist()
    if "Scan.usda" not in names:
        raise ValueError("USDZ nie jest skanem RoomPlan (brak Scan.usda)")
    floors = [name for name in names if "/Floors/Floor" in name and name.endswith(".usda")]
    if not floors:
        raise ValueError("RoomPlan: brak podłogi")
    floor = parse_usda_mesh(archive.read(floors[0]).decode(), name="Floor")
    outline_m = _floor_outline_m(floor)
    origin = (
        min(point[0] for point in outline_m),
        min(point[1] for point in outline_m),
    )
    outer = _ring_mm(outline_m, origin)
    fireplaces: list[Ring] = []
    fireplace_rects: list[str] = []
    thresholds: list[Threshold] = []
    door_polys: list[str] = []
    for name in names:
        if not name.endswith(".usda") or "/Mesh/" not in name:
            continue
        text = archive.read(name).decode()
        mesh = parse_usda_mesh(text, name=name.rsplit("/", 1)[-1].removesuffix(".usda"))
        category = mesh.category.lower()
        if category.startswith("fireplace"):
            ring, rect = _box_ring(mesh, origin)
            fireplaces.append(ring)
            fireplace_rects.append(rect)
        elif category.startswith("door"):
            threshold = _door_threshold(mesh, origin)
            thresholds.append(threshold)
            door_polys.append(_ring_to_vertices_m(threshold.geometry))
    holes = tuple(fireplaces) + tuple(item.geometry for item in thresholds)
    return CapturedScan(
        name=_room_name(archive.read("Scan.usda").decode()),
        room=Room(outer, holes=holes),
        thresholds=tuple(thresholds),
        vertices_m=_ring_to_vertices_m(outer),
        hole_rectangles="\n".join(fireplace_rects),
        door_vertices="\n\n".join(door_polys),
    )


def _room_name(root: str) -> str:
    for key, label in _ROOM_NAMES.items():
        if f"{key}0" in root.lower():
            return label
    return "Pokój"


def _floor_outline_m(floor: UsdaMesh) -> list[tuple[float, float]]:
    top = [index for index, point in enumerate(floor.points) if abs(point[2]) <= _TOP_Z]
    top_set = set(top)
    if len(top) < 3:
        raise ValueError("RoomPlan: podłoga nie ma płaszczyzny")
    cursor = 0
    edge_count: dict[frozenset[int], int] = defaultdict(int)
    for count in floor.counts:
        face = floor.indices[cursor : cursor + count]
        cursor += count
        if count != 3 or not all(index in top_set for index in face):
            continue
        for start, end in ((face[0], face[1]), (face[1], face[2]), (face[2], face[0])):
            edge_count[frozenset((start, end))] += 1
    boundary: dict[int, list[int]] = defaultdict(list)
    for edge, seen in edge_count.items():
        if seen != 1:
            continue
        a, b = tuple(edge)
        boundary[a].append(b)
        boundary[b].append(a)
    if not boundary:
        raise ValueError("RoomPlan: nie da się odczytać obrysu podłogi")
    start = min(boundary, key=lambda index: (_plan(floor, index), index))
    walked = [start]
    previous = start
    current = boundary[start][0]
    while current != start:
        walked.append(current)
        nxt = next(node for node in boundary[current] if node != previous)
        previous, current = current, nxt
        if len(walked) > len(floor.points):
            raise ValueError("RoomPlan: obrys podłogi jest uszkodzony")
    return [_plan(floor, index) for index in walked]


def _plan(mesh: UsdaMesh, index: int) -> tuple[float, float]:
    world = transform_point(mesh.points[index], mesh.matrix)
    return world[0], world[2]


def _box_corners_m(mesh: UsdaMesh) -> list[tuple[float, float]]:
    seen: set[tuple[float, float]] = set()
    corners: list[tuple[float, float]] = []
    for point in mesh.points:
        world = transform_point((point[0], 0.0, point[2]), mesh.matrix)
        key = (round(world[0], 4), round(world[2], 4))
        if key in seen:
            continue
        seen.add(key)
        corners.append((world[0], world[2]))
    if len(corners) < 3:
        raise ValueError(f"RoomPlan: {mesh.name} nie ma rzutu na podłogę")
    return corners


def _ordered_ring_m(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
    cx = sum(point[0] for point in points) / len(points)
    cy = sum(point[1] for point in points) / len(points)
    return sorted(points, key=lambda point: math.atan2(point[1] - cy, point[0] - cx))


def _box_ring(mesh: UsdaMesh, origin: tuple[float, float]) -> tuple[Ring, str]:
    ring = _ring_mm(_ordered_ring_m(_box_corners_m(mesh)), origin)
    return ring, _ring_to_rect_m(ring)


def _door_threshold(mesh: UsdaMesh, origin: tuple[float, float]) -> Threshold:
    corners = _ordered_ring_m(_box_corners_m(mesh))
    ring = _ring_mm(corners, origin)
    length_mm, width_mm, long_i = _rect_axes(ring)
    if width_mm < THRESHOLD_MM:
        ring = _expand_width(ring, long_i, THRESHOLD_MM)
        width_mm = THRESHOLD_MM
    return Threshold(
        label="listwa progowa",
        length_mm=length_mm,
        width_mm=width_mm,
        geometry=ring,
    )


def _rect_axes(ring: Ring) -> tuple[int, int, int]:
    verts = ring.vertices
    edges = []
    for index, vertex in enumerate(verts):
        nxt = verts[(index + 1) % len(verts)]
        length = int(round(math.hypot(nxt.x_mm - vertex.x_mm, nxt.y_mm - vertex.y_mm)))
        edges.append((length, index))
    long_len, long_i = max(edges)
    short_len = min(edge[0] for edge in edges)
    return long_len, short_len, long_i


def _expand_width(ring: Ring, long_i: int, width_mm: int) -> Ring:
    verts = ring.vertices
    a = verts[long_i]
    b = verts[(long_i + 1) % len(verts)]
    dx, dy = b.x_mm - a.x_mm, b.y_mm - a.y_mm
    length = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / length, dx / length
    _, current, _ = _rect_axes(ring)
    extra = (width_mm - current) / 2
    grown = []
    cx = sum(v.x_mm for v in verts) / len(verts)
    cy = sum(v.y_mm for v in verts) / len(verts)
    for vertex in verts:
        side = 1 if (vertex.x_mm - cx) * nx + (vertex.y_mm - cy) * ny >= 0 else -1
        grown.append(
            Vertex(
                int(round(vertex.x_mm + side * extra * nx)),
                int(round(vertex.y_mm + side * extra * ny)),
            )
        )
    return Ring(tuple(grown))


def _ring_mm(points: list[tuple[float, float]], origin: tuple[float, float]) -> Ring:
    verts = tuple(
        Vertex(
            metres_to_mm_coord(f"{point[0] - origin[0]:.6f}"),
            metres_to_mm_coord(f"{point[1] - origin[1]:.6f}"),
        )
        for point in points
    )
    path = normalize_ring(tuple((v.x_mm, v.y_mm) for v in verts))
    start = min(range(len(path)), key=lambda i: (path[i][0], path[i][1], i))
    rotated = path[start:] + path[:start]
    return Ring(tuple(Vertex(x, y) for x, y in rotated))


def _ring_to_vertices_m(ring: Ring) -> str:
    return "\n".join(f"{v.x_mm / 1000:.3f},{v.y_mm / 1000:.3f}" for v in ring.vertices)


def _ring_to_rect_m(ring: Ring) -> str:
    xs = [v.x_mm for v in ring.vertices]
    ys = [v.y_mm for v in ring.vertices]
    min_x, min_y = min(xs), min(ys)
    width_m = (max(xs) - min_x) / 1000
    height_m = (max(ys) - min_y) / 1000
    return f"{min_x / 1000:.3f},{min_y / 1000:.3f},{width_m:.3f},{height_m:.3f}"
