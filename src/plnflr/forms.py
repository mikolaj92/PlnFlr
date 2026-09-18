"""HTTP input for a layout request."""

from __future__ import annotations

from dataclasses import replace
from typing import Literal

from fastapi import Request
from pydantic import BaseModel

from plnflr.domain.constructors import l_shape, rectangle
from plnflr.domain.models import (
    LayoutPlan,
    LayoutRules,
    Opening,
    PlankSpec,
    Ring,
    Room,
    Threshold,
    TileSpec,
    Vertex,
    Zone,
)
from plnflr.domain.units import metres_to_mm, metres_to_mm_coord
from plnflr.engine.layout import layout_floor


class LayoutForm(BaseModel):
    shape: Literal["rect", "l", "polygon"] = "rect"
    kind: Literal["plank", "tile"] = "plank"
    kind_b: Literal["plank", "tile"] = "tile"
    width_m: str = "4.000"
    height_m: str = "3.000"
    l_span_x_m: str = "6.000"
    l_span_y_m: str = "4.000"
    l_cutout_x_m: str = "2.500"
    l_cutout_y_m: str = "2.000"
    vertices: str = ""
    hole_rectangles: str = ""
    hole_vertices: str = ""
    door_rectangles: str = ""
    door_vertices: str = ""
    window_segments: str = ""
    plank_length_m: str = "1.383"
    plank_width_m: str = "0.156"
    boards_per_pack: str = "8"
    tile_length_m: str = "0.600"
    tile_width_m: str = "0.600"
    grout_mm: str = "3"
    expansion_mm: str = ""
    direction: Literal["along_long", "along_short", "into_window"] = "along_long"
    stagger: Literal["third", "half"] = "third"
    angle_deg: str = "0"
    split: Literal["none", "x", "y"] = "none"
    split_at_m: str = ""


async def layout_form_from_request(request: Request) -> LayoutForm:
    """Collect the layout POST once, using ``LayoutForm`` as the field schema."""
    posted = await request.form()
    return LayoutForm.model_validate({key: value for key, value in posted.items()})


def _positive_int(raw: str, *, field: str) -> int | None:
    text = raw.strip()
    if not text:
        return None
    try:
        value = int(text)
    except ValueError as exc:
        raise ValueError(f"{field} musi być liczbą całkowitą") from exc
    if value <= 0:
        raise ValueError(f"{field} musi być dodatnie")
    return value


def _non_negative_int(raw: str, *, field: str) -> int | None:
    text = raw.strip()
    if not text:
        return None
    try:
        value = int(text)
    except ValueError as exc:
        raise ValueError(f"{field} musi być liczbą całkowitą") from exc
    if value < 0:
        raise ValueError(f"{field} nie może być ujemne")
    return value


def _angle_deg(raw: str) -> int:
    text = raw.strip() or "0"
    try:
        value = int(text)
    except ValueError as exc:
        raise ValueError("kąt musi być liczbą całkowitą w stopniach") from exc
    return value % 360


def parse_vertices(raw: str) -> Ring:
    points: list[Vertex] = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        line = line.replace(";", ",")
        parts = [p.strip() for p in line.split(",") if p.strip()]
        if len(parts) != 2:
            raise ValueError("każdy wierzchołek to x,y w metrach")
        points.append(Vertex(metres_to_mm_coord(parts[0]), metres_to_mm_coord(parts[1])))
    return Ring(tuple(points))


def _rectangular_holes(raw: str) -> list[Ring]:
    holes: list[Ring] = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = [part.strip() for part in line.replace(";", ",").split(",")]
        if len(parts) != 4 or any(not part for part in parts):
            raise ValueError("każdy prostokątny otwór to x,y,szerokość,wysokość w metrach")
        x = metres_to_mm_coord(parts[0])
        y = metres_to_mm_coord(parts[1])
        width = metres_to_mm(parts[2])
        height = metres_to_mm(parts[3])
        holes.append(
            Ring(
                (
                    Vertex(x, y),
                    Vertex(x + width, y),
                    Vertex(x + width, y + height),
                    Vertex(x, y + height),
                )
            )
        )
    return holes


def _polygonal_holes(raw: str) -> list[Ring]:
    holes: list[Ring] = []
    lines: list[str] = []
    for line in (*raw.splitlines(), ""):
        if line.strip():
            lines.append(line)
        elif lines:
            holes.append(parse_vertices("\n".join(lines)))
            lines = []
    return holes


def room_from_form(form: LayoutForm) -> Room:
    if form.shape == "rect":
        outer = rectangle(metres_to_mm(form.width_m), metres_to_mm(form.height_m)).outer
    elif form.shape == "l":
        outer = l_shape(
            span_x_mm=metres_to_mm(form.l_span_x_m),
            span_y_mm=metres_to_mm(form.l_span_y_m),
            cutout_x_mm=metres_to_mm(form.l_cutout_x_m),
            cutout_y_mm=metres_to_mm(form.l_cutout_y_m),
        ).outer
    else:
        outer = parse_vertices(form.vertices)
    holes = (*_rectangular_holes(form.hole_rectangles), *_polygonal_holes(form.hole_vertices))
    return Room(outer, holes=holes)


def rules_from_form(form: LayoutForm) -> LayoutRules:
    expansion = _non_negative_int(form.expansion_mm, field="dylatacja")
    return LayoutRules(
        expansion_mm=expansion,
        stagger=form.stagger,
        direction=form.direction,
        angle_deg=_angle_deg(form.angle_deg),
    )


def plank_from_form(form: LayoutForm) -> PlankSpec:
    pack = _positive_int(form.boards_per_pack, field="sztuk w paczce")
    return PlankSpec(
        length_mm=metres_to_mm(form.plank_length_m),
        width_mm=metres_to_mm(form.plank_width_m),
        boards_per_pack=pack,
    )


def tile_from_form(form: LayoutForm) -> TileSpec:
    grout = _positive_int(form.grout_mm, field="fuga") or 0
    return TileSpec(
        length_mm=metres_to_mm(form.tile_length_m),
        width_mm=metres_to_mm(form.tile_width_m),
        grout_mm=grout,
    )


def _zone(form: LayoutForm, kind: Literal["plank", "tile"], label: str) -> Zone:
    if kind == "tile":
        return Zone(kind="tile", tile=tile_from_form(form), label=label)
    return Zone(kind="plank", plank=plank_from_form(form), label=label)


def _threshold_from_ring(ring: Ring) -> Threshold:
    verts = ring.vertices
    edges = [
        int(
            round(
                ((nxt.x_mm - vertex.x_mm) ** 2 + (nxt.y_mm - vertex.y_mm) ** 2) ** 0.5
            )
        )
        for vertex, nxt in zip(verts, verts[1:] + verts[:1], strict=True)
    ]
    return Threshold(
        label="listwa progowa",
        length_mm=max(edges),
        width_mm=min(edges),
        geometry=ring,
    )


def _window_openings(raw: str) -> tuple[Opening, ...]:
    openings: list[Opening] = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = [part.strip() for part in line.replace(";", ",").split(",")]
        if len(parts) != 4 or any(not part for part in parts):
            raise ValueError("każde okno to x1,y1,x2,y2 w metrach")
        openings.append(
            Opening(
                label="okno",
                start=Vertex(metres_to_mm_coord(parts[0]), metres_to_mm_coord(parts[1])),
                end=Vertex(metres_to_mm_coord(parts[2]), metres_to_mm_coord(parts[3])),
            )
        )
    return tuple(openings)


def layout_from_form(form: LayoutForm) -> LayoutPlan:
    room = room_from_form(form)
    door_rings = tuple(
        (*_rectangular_holes(form.door_rectangles), *_polygonal_holes(form.door_vertices))
    )
    if door_rings:
        room = Room(room.outer, holes=(*room.holes, *door_rings))
    windows = _window_openings(form.window_segments)
    rules = rules_from_form(form)
    if form.split == "none":
        label = "Płytki" if form.kind == "tile" else "Panele"
        plan = layout_floor(
            room, (_zone(form, form.kind, label),), rules, windows=windows
        )
    else:
        split_at = metres_to_mm(form.split_at_m) if form.split_at_m.strip() else None
        plan = layout_floor(
            room,
            (
                _zone(form, form.kind, "Strefa A"),
                _zone(form, form.kind_b, "Strefa B"),
            ),
            rules,
            split_axis=form.split,
            split_at_mm=split_at,
            windows=windows,
        )
    if not door_rings:
        return plan
    return replace(
        plan,
        thresholds=tuple(_threshold_from_ring(ring) for ring in door_rings),
    )
