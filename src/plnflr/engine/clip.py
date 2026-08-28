"""Integer polygon clip and inset. The only pyclipper import."""

from __future__ import annotations

from collections.abc import Sequence

import pyclipper

from plnflr.domain.models import Ring, Vertex

Point = tuple[int, int]
Path = tuple[Point, ...]


def ring_to_tuple(ring: Ring) -> Path:
    return tuple((v.x_mm, v.y_mm) for v in ring.vertices)


def tuple_to_ring(path: Sequence[Point]) -> Ring:
    return Ring(tuple(Vertex(int(x), int(y)) for x, y in path))


def area_mm2(outer: Sequence[Point]) -> int:
    return abs(int(round(pyclipper.Area(list(outer)))))


def orientation_ccw(outer: Sequence[Point]) -> bool:
    return pyclipper.Orientation(list(outer)) is False


def normalize_ring(outer: Sequence[Point]) -> Path:
    points = [(int(x), int(y)) for x, y in outer]
    if pyclipper.Orientation(points):
        points = list(reversed(points))
    return tuple(points)


def _clean(path: Sequence[Point]) -> Path:
    points = [(int(x), int(y)) for x, y in path]
    if len(points) >= 2 and points[0] == points[-1]:
        points = points[:-1]
    return tuple(points)


def validate_room(outer: Sequence[Point], holes: Sequence[Sequence[Point]]) -> None:
    path = list(_clean(outer))
    if len(path) < 3:
        raise ValueError("ring needs ≥ 3 vertices")
    simple = pyclipper.SimplifyPolygon(path, pyclipper.PFT_NONZERO)
    if len(simple) != 1:
        raise ValueError("self-intersecting polygon")
    if abs(int(round(pyclipper.Area(simple[0])))) != area_mm2(path) and abs(
        pyclipper.Area(path)
    ) == 0:
        raise ValueError("self-intersecting polygon")
    # Clipper Orientation True = CW. A bowtie area is near zero.
    if abs(pyclipper.Area(path)) < 1:
        raise ValueError("self-intersecting polygon")
    pc = pyclipper.Pyclipper()
    try:
        pc.AddPath(path, pyclipper.PT_SUBJECT, True)
        for hole in holes:
            pc.AddPath(list(_clean(hole)), pyclipper.PT_CLIP, True)
    except pyclipper.ClipperException as exc:
        raise ValueError("self-intersecting polygon") from exc


def inset(
    outer: Sequence[Point],
    holes: Sequence[Sequence[Point]],
    gap_mm: int,
) -> tuple[Path, tuple[Path, ...]]:
    if gap_mm < 0:
        raise ValueError("expansion must be >= 0")
    if gap_mm == 0:
        return normalize_ring(_clean(outer)), tuple(normalize_ring(_clean(h)) for h in holes)
    offset = pyclipper.PyclipperOffset()
    offset.AddPath(
        list(normalize_ring(_clean(outer))),
        pyclipper.JT_MITER,
        pyclipper.ET_CLOSEDPOLYGON,
    )
    inners = offset.Execute(-gap_mm)
    if not inners:
        raise ValueError("expansion gap leaves no installable area")
    inner = tuple((int(x), int(y)) for x, y in inners[0])
    grown: list[Path] = []
    for hole in holes:
        ho = pyclipper.PyclipperOffset()
        ho.AddPath(
            list(normalize_ring(_clean(hole))),
            pyclipper.JT_MITER,
            pyclipper.ET_CLOSEDPOLYGON,
        )
        outs = ho.Execute(gap_mm)
        if outs:
            grown.append(tuple((int(x), int(y)) for x, y in outs[0]))
    return inner, tuple(grown)


def _paths(solution: Sequence[Sequence[Point]]) -> tuple[Path, ...]:
    return tuple(tuple((int(x), int(y)) for x, y in poly) for poly in solution if len(poly) >= 3)


def intersect_rect(
    rect: Sequence[Point],
    outer: Sequence[Point],
    holes: Sequence[Sequence[Point]],
) -> tuple[Path, ...]:
    pc = pyclipper.Pyclipper()
    pc.AddPath(list(_clean(rect)), pyclipper.PT_SUBJECT, True)
    pc.AddPath(list(normalize_ring(_clean(outer))), pyclipper.PT_CLIP, True)
    solution = pc.Execute(
        pyclipper.CT_INTERSECTION,
        pyclipper.PFT_NONZERO,
        pyclipper.PFT_NONZERO,
    )
    for hole in holes:
        if not solution:
            break
        cut = pyclipper.Pyclipper()
        cut.AddPaths(list(solution), pyclipper.PT_SUBJECT, True)
        cut.AddPath(list(normalize_ring(_clean(hole))), pyclipper.PT_CLIP, True)
        solution = cut.Execute(
            pyclipper.CT_DIFFERENCE,
            pyclipper.PFT_NONZERO,
            pyclipper.PFT_NONZERO,
        )
    return _paths(solution)
