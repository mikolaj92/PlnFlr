import pytest

from plnflr.domain.constructors import l_shape, rectangle
from plnflr.domain.models import Ring, Room, Vertex


def test_ring_requires_at_least_three_vertices() -> None:
    with pytest.raises(ValueError):
        Ring((Vertex(0, 0), Vertex(1, 0)))


def test_rectangle_has_four_vertices_and_expected_size() -> None:
    room = rectangle(4000, 3000)
    assert len(room.outer.vertices) == 4
    assert room.holes == ()
    xs = [v.x_mm for v in room.outer.vertices]
    ys = [v.y_mm for v in room.outer.vertices]
    assert min(xs) == 0 and max(xs) == 4000
    assert min(ys) == 0 and max(ys) == 3000


def test_l_shape_has_six_vertices() -> None:
    room = l_shape(span_x_mm=6000, span_y_mm=4000, cutout_x_mm=2500, cutout_y_mm=2000)
    assert len(room.outer.vertices) == 6
    assert room.holes == ()


def test_room_accepts_holes() -> None:
    outer = rectangle(4000, 3000).outer
    hole = Ring(
        (
            Vertex(1500, 1000),
            Vertex(2500, 1000),
            Vertex(2500, 2000),
            Vertex(1500, 2000),
        )
    )
    room = Room(outer, (hole,))
    assert len(room.holes) == 1
