from plnflr.domain.constructors import rectangle
from plnflr.domain.models import LayoutRules, Ring, Room, Vertex
from plnflr.engine.clip import area_mm2, ring_to_tuple
from plnflr.engine.expansion import inset_room, resolve_gap_mm


def test_explicit_gap_on_rectangle() -> None:
    room = rectangle(4000, 3000)
    gap = resolve_gap_mm(room, LayoutRules(expansion_mm=12))
    inner = inset_room(room, gap)
    assert gap == 12
    assert area_mm2(ring_to_tuple(inner.outer)) == 3976 * 2976


def test_auto_gap_uses_longest_bbox_side() -> None:
    room = rectangle(8000, 3000)
    assert resolve_gap_mm(room, LayoutRules()) == 12


def test_auto_gap_respects_minimum() -> None:
    room = rectangle(4000, 3000)
    assert resolve_gap_mm(room, LayoutRules()) == 10


def test_hole_grows_by_gap() -> None:
    outer = rectangle(4000, 4000).outer
    hole = Ring((Vertex(1500, 1500), Vertex(2500, 1500), Vertex(2500, 2500), Vertex(1500, 2500)))
    room = Room(outer, (hole,))
    inner = inset_room(room, 10)
    assert len(inner.holes) == 1
    xs = [v.x_mm for v in inner.holes[0].vertices]
    ys = [v.y_mm for v in inner.holes[0].vertices]
    assert min(xs) == 1490 and max(xs) == 2510
    assert min(ys) == 1490 and max(ys) == 2510
