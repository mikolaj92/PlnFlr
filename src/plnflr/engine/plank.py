"""Lay planks: bbox grid clipped to the inset polygon."""

from __future__ import annotations

from dataclasses import replace
from typing import Literal

from plnflr.domain.models import (
    LayoutPlan,
    LayoutRules,
    Piece,
    PlankSpec,
    Room,
    Vertex,
    Warning,
)
from plnflr.engine.bom import make_bom
from plnflr.engine.clip import area_mm2, intersect_rect, ring_to_tuple
from plnflr.engine.expansion import bbox, inset_room, resolve_gap_mm
from plnflr.engine.grid import iter_slots
from plnflr.engine.instructions import instructions_for
from plnflr.engine.rotate import origin_of, rotate_points, rotate_room


def _direction(room: Room, rules: LayoutRules) -> Literal["along_x", "along_y"]:
    if rules.direction in {"along_x", "along_y"}:
        return rules.direction
    min_x, min_y, max_x, max_y = bbox(room)
    along_long = (max_x - min_x) >= (max_y - min_y)
    if rules.direction == "along_short":
        along_long = not along_long
    return "along_x" if along_long else "along_y"


def _lay_axis(
    inner: Room, spec: PlankSpec, rules: LayoutRules
) -> tuple[tuple[Piece, ...], Literal["along_x", "along_y"], list[Warning]]:
    direction = _direction(inner, rules)
    min_x, min_y, max_x, max_y = bbox(inner)
    span = max(max_x - min_x, max_y - min_y)
    warnings: list[Warning] = []
    if span > rules.intermediate_joint_mm:
        metres = f"{span / 1000:.3f}".replace(".", ",")
        warnings.append(
            Warning(
                "intermediate_joint",
                f"Pomieszczenie ma {metres} m w świetle po dylatacji. "
                "Rozważ przerwę dylatacyjną / profil co ok. 8 m.",
            )
        )
    slots = iter_slots(
        min_x=min_x,
        min_y=min_y,
        max_x=max_x,
        max_y=max_y,
        plank_length_mm=spec.length_mm,
        plank_width_mm=spec.width_mm,
        min_row_width_mm=rules.min_row_width_mm,
        min_end_mm=rules.min_end_length_mm,
        stagger=rules.stagger,
        direction=direction,
    )
    outer_path = ring_to_tuple(inner.outer)
    hole_paths = tuple(ring_to_tuple(h) for h in inner.holes)
    pieces: list[Piece] = []
    board = 0
    order = 0
    for slot in slots:
        rect = (
            (slot.x0, slot.y0),
            (slot.x1, slot.y0),
            (slot.x1, slot.y1),
            (slot.x0, slot.y1),
        )
        clipped = intersect_rect(rect, outer_path, hole_paths)
        if not clipped:
            continue
        board += 1
        for poly in clipped:
            order += 1
            kind = slot.kind if len(poly) == 4 else "clip"
            along = (slot.x1 - slot.x0) if direction == "along_x" else (slot.y1 - slot.y0)
            across = (slot.y1 - slot.y0) if direction == "along_x" else (slot.x1 - slot.x0)
            pieces.append(
                Piece(
                    piece_id=f"r{slot.row_index}-b{board}-{order}",
                    row_index=slot.row_index,
                    geometry=tuple(Vertex(x, y) for x, y in poly),
                    kind=kind,  # type: ignore[arg-type]
                    source_board=board,
                    install_order=order,
                    length_mm=along,
                    width_mm=across,
                )
            )
    return tuple(pieces), direction, warnings


def layout_planks(room: Room, spec: PlankSpec, rules: LayoutRules) -> LayoutPlan:
    gap = resolve_gap_mm(room, rules)
    inner = inset_room(room, gap)
    angle = int(rules.angle_deg) % 360
    origin = origin_of(inner)
    grid_room = rotate_room(inner, angle, origin) if angle else inner
    pieces, direction, warnings = _lay_axis(grid_room, spec, rules)
    if angle:
        pieces = tuple(
            replace(
                piece,
                geometry=tuple(
                    Vertex(x, y)
                    for x, y in rotate_points(
                        tuple((v.x_mm, v.y_mm) for v in piece.geometry),
                        -angle,
                        origin,
                    )
                ),
            )
            for piece in pieces
        )
    outer_path = ring_to_tuple(inner.outer)
    hole_paths = tuple(ring_to_tuple(h) for h in inner.holes)
    net = area_mm2(outer_path) - sum(area_mm2(h) for h in hole_paths)
    bom = make_bom(
        pieces=len(pieces),
        full_boards=max((p.source_board for p in pieces), default=0),
        boards_per_pack=spec.boards_per_pack,
        area_net_mm2=net,
        board_area_mm2=spec.length_mm * spec.width_mm,
        label="Panele",
        kind="plank",
    )
    min_x, min_y, max_x, max_y = bbox(inner)
    longer_x = (max_x - min_x) >= (max_y - min_y)
    axis = "dłuższego" if direction == "along_x" and longer_x else "wybranego"
    angle_note = f" Kąt {angle}°." if angle else ""
    rationale = (
        f"Kierunek {direction.replace('_', ' ')} — deski wzdłuż {axis} boku. "
        f"Dylatacja {gap} mm. Siatka na bbox, przycięcie do obrysu.{angle_note}"
    )
    return LayoutPlan(
        room=room,
        gap_mm=gap,
        inset=inner,
        direction=direction,
        pieces=pieces,
        bom=bom,
        warnings=tuple(warnings),
        rationale_pl=rationale,
        rows_instruction_pl=instructions_for(
            pieces, gap_mm=gap, has_holes=bool(room.holes)
        ),
        angle_deg=angle,
        boms=(bom,),
    )
