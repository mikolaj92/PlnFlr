from plnflr.domain.constructors import rectangle
from plnflr.domain.models import LayoutRules, TileSpec
from plnflr.engine.tile import layout_tiles


def test_tiles_cover_inset() -> None:
    plan = layout_tiles(
        rectangle(2010, 2010),
        TileSpec(length_mm=600, width_mm=600, grout_mm=3),
        LayoutRules(expansion_mm=10),
    )
    assert plan.pieces
    assert plan.bom.full_boards > 0
