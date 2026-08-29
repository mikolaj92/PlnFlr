"""Split a room on an axis-aligned dividing line."""

from __future__ import annotations

from typing import Literal

from plnflr.domain.models import Room
from plnflr.engine.clip import area_mm2, intersect_polygon, ring_to_tuple, tuple_to_ring
from plnflr.engine.expansion import bbox

_PAD = 100


def split_room(
    room: Room,
    *,
    axis: Literal["x", "y"],
    at_mm: int,
) -> tuple[Room | None, Room | None]:
    min_x, min_y, max_x, max_y = bbox(room)
    if axis == "x":
        first_clip = (
            (min_x - _PAD, min_y - _PAD),
            (at_mm, min_y - _PAD),
            (at_mm, max_y + _PAD),
            (min_x - _PAD, max_y + _PAD),
        )
        second_clip = (
            (at_mm, min_y - _PAD),
            (max_x + _PAD, min_y - _PAD),
            (max_x + _PAD, max_y + _PAD),
            (at_mm, max_y + _PAD),
        )
    else:
        first_clip = (
            (min_x - _PAD, min_y - _PAD),
            (max_x + _PAD, min_y - _PAD),
            (max_x + _PAD, at_mm),
            (min_x - _PAD, at_mm),
        )
        second_clip = (
            (min_x - _PAD, at_mm),
            (max_x + _PAD, at_mm),
            (max_x + _PAD, max_y + _PAD),
            (min_x - _PAD, max_y + _PAD),
        )
    return _clip_room(room, first_clip), _clip_room(room, second_clip)


def _clip_room(room: Room, clip: tuple[tuple[int, int], ...]) -> Room | None:
    outers = intersect_polygon(ring_to_tuple(room.outer), clip)
    if not outers:
        return None
    outer = max(outers, key=area_mm2)
    holes: list[tuple[tuple[int, int], ...]] = []
    for hole in room.holes:
        holes.extend(intersect_polygon(ring_to_tuple(hole), clip))
    kept = tuple(tuple_to_ring(hole) for hole in holes if len(hole) >= 3)
    return Room(tuple_to_ring(outer), kept)
