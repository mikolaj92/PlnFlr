from plnflr.domain.constructors import rectangle
from plnflr.engine.clip import area_mm2, ring_to_tuple
from plnflr.engine.split import split_room


def test_split_rectangle_on_x_keeps_area() -> None:
    room = rectangle(4000, 3000)
    left, right = split_room(room, axis="x", at_mm=1500)
    assert left is not None and right is not None
    left_area = area_mm2(ring_to_tuple(left.outer))
    right_area = area_mm2(ring_to_tuple(right.outer))
    assert left_area == 1500 * 3000
    assert right_area == 2500 * 3000
