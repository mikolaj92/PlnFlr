"""Server-side SVG of the whole install."""

from __future__ import annotations

from plnflr.domain.models import LayoutPlan, Ring
from plnflr.engine.expansion import bbox


def _path(ring: Ring) -> str:
    verts = ring.vertices
    if not verts:
        return ""
    start = verts[0]
    parts = [f"M {start.x_mm} {start.y_mm}"]
    for v in verts[1:]:
        parts.append(f"L {v.x_mm} {v.y_mm}")
    parts.append("Z")
    return " ".join(parts)


def _poly_path(points: tuple) -> str:
    if not points:
        return ""
    start = points[0]
    parts = [f"M {start.x_mm} {start.y_mm}"]
    for v in points[1:]:
        parts.append(f"L {v.x_mm} {v.y_mm}")
    parts.append("Z")
    return " ".join(parts)


def plan_to_svg(plan: LayoutPlan, *, max_px: int = 900) -> str:
    min_x, min_y, max_x, max_y = bbox(plan.room)
    width = max(max_x - min_x, 1)
    height = max(max_y - min_y, 1)
    evenodd = _path(plan.room.outer)
    for hole in plan.room.holes:
        evenodd += " " + _path(hole)
    gap_path = _path(plan.room.outer) + " " + _path(plan.inset.outer)
    for hole in plan.room.holes:
        gap_path += " " + _path(hole)
    for hole in plan.inset.holes:
        gap_path += " " + _path(hole)
    pieces = []
    for piece in plan.pieces:
        cls = "pln-row-even" if piece.row_index % 2 == 0 else "pln-row-odd"
        if piece.kind in {"clip", "rip", "tile_cut"}:
            cls += " pln-clip"
        pieces.append(
            f'<path class="{cls}" data-piece-id="{piece.piece_id}" '
            f'd="{_poly_path(piece.geometry)}" />'
        )
    labels = []
    seen: set[int] = set()
    for piece in plan.pieces:
        if piece.row_index in seen:
            continue
        seen.add(piece.row_index)
        xs = [v.x_mm for v in piece.geometry]
        ys = [v.y_mm for v in piece.geometry]
        cx = (min(xs) + max(xs)) // 2
        cy = (min(ys) + max(ys)) // 2
        labels.append(
            f'<text class="pln-label" x="{cx}" y="{cy}" text-anchor="middle" '
            f'dominant-baseline="middle">{piece.row_index + 1}</text>'
        )
    body = "\n".join(
        [
            f'<path class="pln-room" fill-rule="evenodd" d="{evenodd}" />',
            f'<path class="pln-gap" fill-rule="evenodd" d="{gap_path}" />',
            *pieces,
            *labels,
        ]
    )
    return (
        f'<svg class="pln-preview" xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="{min_x} {min_y} {width} {height}" '
        f'width="{max_px}" role="img" aria-label="Plan ułożenia podłogi">'
        f"{body}</svg>"
    )
