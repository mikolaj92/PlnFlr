"""Integer-mm rotation. Multiples of 90° stay exact."""

from __future__ import annotations

from math import cos, radians, sin

from plnflr.domain.models import Ring, Room, Vertex
from plnflr.engine.clip import ring_to_tuple, tuple_to_ring
from plnflr.engine.expansion import bbox

Point = tuple[int, int]

_EXACT = {
    0: (1, 0),
    90: (0, 1),
    180: (-1, 0),
    270: (0, -1),
}


def rotate_points(
    points: tuple[Point, ...],
    angle_deg: int,
    origin: Point = (0, 0),
) -> tuple[Point, ...]:
    angle = int(angle_deg) % 360
    ox, oy = origin
    if angle in _EXACT:
        cosine, sine = _EXACT[angle]
        return tuple(
            (ox + (x - ox) * cosine - (y - oy) * sine, oy + (x - ox) * sine + (y - oy) * cosine)
            for x, y in points
        )
    rad = radians(angle)
    cosine, sine = cos(rad), sin(rad)
    rotated: list[Point] = []
    for x, y in points:
        dx, dy = x - ox, y - oy
        rotated.append(
            (int(round(ox + dx * cosine - dy * sine)), int(round(oy + dx * sine + dy * cosine)))
        )
    return tuple(rotated)


def origin_of(room: Room) -> Point:
    min_x, min_y, max_x, max_y = bbox(room)
    return ((min_x + max_x) // 2, (min_y + max_y) // 2)


def rotate_room(room: Room, angle_deg: int, origin: Point) -> Room:
    if int(angle_deg) % 360 == 0:
        return room
    outer = rotate_points(ring_to_tuple(room.outer), angle_deg, origin)
    holes = tuple(rotate_points(ring_to_tuple(hole), angle_deg, origin) for hole in room.holes)
    hole_rings = tuple(Ring(tuple(Vertex(x, y) for x, y in hole)) for hole in holes)
    return Room(tuple_to_ring(outer), hole_rings)
