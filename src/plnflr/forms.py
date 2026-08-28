"""HTTP input for a layout request."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel

from plnflr.domain.constructors import l_shape, rectangle
from plnflr.domain.models import (
    LayoutRules,
    PlankSpec,
    Ring,
    Room,
    TileSpec,
    Vertex,
)
from plnflr.domain.units import metres_to_mm


class LayoutForm(BaseModel):
    shape: Literal["rect", "l", "polygon"] = "rect"
    kind: Literal["plank", "tile"] = "plank"
    width_m: str = "4.000"
    height_m: str = "3.000"
    l_span_x_m: str = "6.000"
    l_span_y_m: str = "4.000"
    l_cutout_x_m: str = "2.500"
    l_cutout_y_m: str = "2.000"
    vertices: str = ""
    plank_length_m: str = "1.383"
    plank_width_m: str = "0.156"
    boards_per_pack: str = "8"
    tile_length_m: str = "0.600"
    tile_width_m: str = "0.600"
    grout_mm: str = "3"
    expansion_mm: str = ""
    direction: Literal["along_long", "along_short"] = "along_long"
    stagger: Literal["third", "half"] = "third"


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
        points.append(Vertex(metres_to_mm(parts[0]), metres_to_mm(parts[1])))
    return Ring(tuple(points))


def room_from_form(form: LayoutForm) -> Room:
    if form.shape == "rect":
        return rectangle(metres_to_mm(form.width_m), metres_to_mm(form.height_m))
    if form.shape == "l":
        return l_shape(
            span_x_mm=metres_to_mm(form.l_span_x_m),
            span_y_mm=metres_to_mm(form.l_span_y_m),
            cutout_x_mm=metres_to_mm(form.l_cutout_x_m),
            cutout_y_mm=metres_to_mm(form.l_cutout_y_m),
        )
    return Room(parse_vertices(form.vertices))


def rules_from_form(form: LayoutForm) -> LayoutRules:
    expansion = None
    if form.expansion_mm.strip():
        expansion = _positive_int(form.expansion_mm, field="dylatacja")
        if expansion is None:
            expansion = 0
    return LayoutRules(
        expansion_mm=expansion,
        stagger=form.stagger,
        direction=form.direction,
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
