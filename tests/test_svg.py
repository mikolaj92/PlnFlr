from plnflr.domain.constructors import rectangle
from plnflr.domain.models import LayoutRules, PlankSpec
from plnflr.engine.plank import layout_planks
from plnflr.render.svg import plan_to_svg


def test_svg_has_viewbox_and_pieces() -> None:
    plan = layout_planks(
        rectangle(4000, 3000),
        PlankSpec(1383, 156),
        LayoutRules(expansion_mm=10),
    )
    svg = plan_to_svg(plan)
    assert "<svg" in svg
    assert "viewBox" in svg
    assert svg.count("<path") + svg.count("<rect") >= len(plan.pieces)
