from plnflr.domain.constructors import rectangle
from plnflr.domain.models import LayoutRules, PlankSpec
from plnflr.engine.plank import layout_planks


def _axis_aligned(geometry) -> bool:
    xs = {v.x_mm for v in geometry}
    ys = {v.y_mm for v in geometry}
    return len(xs) <= 2 and len(ys) <= 2


def test_zero_angle_stays_axis_aligned() -> None:
    plan = layout_planks(
        rectangle(4000, 3000),
        PlankSpec(1383, 156),
        LayoutRules(expansion_mm=10, angle_deg=0),
    )
    assert plan.angle_deg == 0
    assert any(_axis_aligned(p.geometry) for p in plan.pieces)


def test_45_degree_pieces_are_rotated() -> None:
    plan = layout_planks(
        rectangle(4000, 3000),
        PlankSpec(1383, 156),
        LayoutRules(expansion_mm=10, angle_deg=45),
    )
    assert plan.angle_deg == 45
    assert plan.pieces
    assert any(not _axis_aligned(p.geometry) for p in plan.pieces)
    assert "45" in plan.rationale_pl
