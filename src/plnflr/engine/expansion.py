"""Expansion gap: inset the outer ring, outset holes."""

from __future__ import annotations

from decimal import ROUND_CEILING, Decimal

from plnflr.domain.models import LayoutRules, Room
from plnflr.engine.clip import inset, ring_to_tuple, tuple_to_ring


def bbox(room: Room) -> tuple[int, int, int, int]:
    xs = [v.x_mm for v in room.outer.vertices]
    ys = [v.y_mm for v in room.outer.vertices]
    return min(xs), min(ys), max(xs), max(ys)


def resolve_gap_mm(room: Room, rules: LayoutRules) -> int:
    if rules.expansion_mm is not None:
        if rules.expansion_mm < 0:
            raise ValueError("expansion must be >= 0")
        return rules.expansion_mm
    min_x, min_y, max_x, max_y = bbox(room)
    longest_m = Decimal(max(max_x - min_x, max_y - min_y)) / Decimal(1000)
    auto = (longest_m * Decimal(rules.expansion_per_m_mm)).to_integral_value(ROUND_CEILING)
    return max(rules.expansion_min_mm, int(auto))


def inset_room(room: Room, gap_mm: int) -> Room:
    inner, holes = inset(
        ring_to_tuple(room.outer),
        tuple(ring_to_tuple(h) for h in room.holes),
        gap_mm,
    )
    return Room(tuple_to_ring(inner), tuple(tuple_to_ring(h) for h in holes))
