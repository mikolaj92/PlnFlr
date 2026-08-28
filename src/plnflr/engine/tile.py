"""Centered tile grid clipped to the inset polygon."""

from __future__ import annotations

from plnflr.domain.models import (
    LayoutPlan,
    LayoutRules,
    Piece,
    Room,
    TileSpec,
    Vertex,
)
from plnflr.engine.bom import make_bom
from plnflr.engine.clip import area_mm2, intersect_rect, ring_to_tuple
from plnflr.engine.expansion import bbox, inset_room, resolve_gap_mm
from plnflr.engine.instructions import instructions_for


def layout_tiles(room: Room, spec: TileSpec, rules: LayoutRules) -> LayoutPlan:
    gap = resolve_gap_mm(room, rules)
    inner = inset_room(room, gap)
    min_x, min_y, max_x, max_y = bbox(inner)
    inner_w = max_x - min_x
    inner_h = max_y - min_y
    pitch_x = spec.length_mm + spec.grout_mm
    pitch_y = spec.width_mm + spec.grout_mm
    cols = max(1, (inner_w + spec.grout_mm) // pitch_x)
    rows = max(1, (inner_h + spec.grout_mm) // pitch_y)
    used_w = cols * spec.length_mm + (cols - 1) * spec.grout_mm
    used_h = rows * spec.width_mm + (rows - 1) * spec.grout_mm
    # If remainder on an edge is too small, add a column/row so cuts grow.
    rem_x = inner_w - used_w
    rem_y = inner_h - used_h
    if 0 < rem_x < rules.min_tile_cut_mm:
        cols += 1
        used_w = cols * spec.length_mm + (cols - 1) * spec.grout_mm
        rem_x = inner_w - used_w
    if 0 < rem_y < rules.min_tile_cut_mm:
        rows += 1
        used_h = rows * spec.width_mm + (rows - 1) * spec.grout_mm
        rem_y = inner_h - used_h
    origin_x = min_x + rem_x // 2
    origin_y = min_y + rem_y // 2
    outer_path = ring_to_tuple(inner.outer)
    hole_paths = tuple(ring_to_tuple(h) for h in inner.holes)
    pieces: list[Piece] = []
    board = 0
    order = 0
    for row in range(rows):
        for col in range(cols):
            x0 = origin_x + col * pitch_x
            y0 = origin_y + row * pitch_y
            x1 = x0 + spec.length_mm
            y1 = y0 + spec.width_mm
            rect = ((x0, y0), (x1, y0), (x1, y1), (x0, y1))
            clipped = intersect_rect(rect, outer_path, hole_paths)
            if not clipped:
                continue
            board += 1
            for poly in clipped:
                order += 1
                kind = "tile_full" if len(poly) == 4 else "tile_cut"
                pieces.append(
                    Piece(
                        piece_id=f"t{row}-{col}-{order}",
                        row_index=row,
                        geometry=tuple(Vertex(x, y) for x, y in poly),
                        kind=kind,
                        source_board=board,
                        install_order=order,
                        length_mm=spec.length_mm,
                        width_mm=spec.width_mm,
                    )
                )
    net = area_mm2(outer_path) - sum(area_mm2(h) for h in hole_paths)
    bom = make_bom(
        pieces=len(pieces),
        full_boards=board,
        boards_per_pack=spec.tiles_per_pack,
        area_net_mm2=net,
        board_area_mm2=spec.length_mm * spec.width_mm,
    )
    return LayoutPlan(
        room=room,
        gap_mm=gap,
        inset=inner,
        direction="along_x",
        pieces=tuple(pieces),
        bom=bom,
        warnings=(),
        rationale_pl="Siatka płytek wycentrowana na bbox, przycięta do obrysu.",
        rows_instruction_pl=instructions_for(
            tuple(pieces), gap_mm=gap, has_holes=bool(room.holes)
        ),
    )
