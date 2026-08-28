from collections import Counter

from plnflr.domain.constructors import l_shape, rectangle
from plnflr.domain.models import LayoutRules, PlankSpec, Ring, Room, Vertex
from plnflr.engine.clip import area_mm2
from plnflr.engine.plank import layout_planks


def _covered(plan) -> int:
    return sum(area_mm2(tuple((v.x_mm, v.y_mm) for v in p.geometry)) for p in plan.pieces)


def test_rectangle_pieces_cover_inset() -> None:
    plan = layout_planks(
        rectangle(4000, 3000),
        PlankSpec(length_mm=1383, width_mm=156, boards_per_pack=8),
        LayoutRules(expansion_mm=10),
    )
    assert plan.gap_mm == 10
    assert plan.pieces
    assert abs(_covered(plan) - plan.bom.area_net_mm2) <= max(len(plan.pieces), 1)
    assert all(p.width_mm >= 50 for p in plan.pieces)
    assert plan.bom.full_boards > 0
    assert plan.bom.packs == (plan.bom.full_boards + 7) // 8
    assert "Rząd 1" in "\n".join(plan.rows_instruction_pl)


def test_l_shape_has_pieces() -> None:
    plan = layout_planks(
        l_shape(span_x_mm=6000, span_y_mm=4000, cutout_x_mm=2500, cutout_y_mm=2000),
        PlankSpec(1383, 156),
        LayoutRules(expansion_mm=10),
    )
    assert plan.pieces
    assert abs(_covered(plan) - plan.bom.area_net_mm2) <= max(len(plan.pieces), 1)
    rows = {p.row_index for p in plan.pieces}
    assert len(rows) > 1


def test_triangle_clips() -> None:
    room = Room(Ring((Vertex(0, 0), Vertex(4000, 0), Vertex(0, 3000))))
    plan = layout_planks(room, PlankSpec(1383, 156), LayoutRules(expansion_mm=10))
    assert any(len(p.geometry) > 4 or p.kind == "clip" for p in plan.pieces)
    assert abs(_covered(plan) - plan.bom.area_net_mm2) <= max(2 * len(plan.pieces), 50)


def test_hole_splits_board() -> None:
    room = Room(
        rectangle(4000, 3000).outer,
        holes=(
            Ring((Vertex(1800, 1200), Vertex(2200, 1200), Vertex(2200, 1800), Vertex(1800, 1800))),
        ),
    )
    plan = layout_planks(room, PlankSpec(1383, 156), LayoutRules(expansion_mm=10))
    counts = Counter(p.source_board for p in plan.pieces)
    assert max(counts.values()) >= 2


def test_long_room_warns_intermediate_joint() -> None:
    plan = layout_planks(
        rectangle(12000, 4000),
        PlankSpec(1383, 156),
        LayoutRules(),
    )
    assert any(w.code == "intermediate_joint" for w in plan.warnings)
