from plnflr.domain.constructors import rectangle
from plnflr.domain.models import LayoutRules, PlankSpec, TileSpec, Zone
from plnflr.engine.layout import layout_floor


def test_split_half_plank_half_tile() -> None:
    plan = layout_floor(
        rectangle(4000, 3000),
        zones=(
            Zone(kind="plank", plank=PlankSpec(1383, 156, boards_per_pack=8)),
            Zone(kind="tile", tile=TileSpec(600, 600, grout_mm=3)),
        ),
        rules=LayoutRules(expansion_mm=10),
        split_axis="x",
        split_at_mm=2000,
    )
    kinds = {p.kind for p in plan.pieces}
    assert any(k in {"full", "start_cut", "end_cut", "rip", "clip"} for k in kinds)
    assert any(k in {"tile_full", "tile_cut"} for k in kinds)
    assert len(plan.boms) == 2
    labels = " ".join(b.label for b in plan.boms)
    assert "Panele" in labels
    assert "Płytki" in labels
    assert plan.split_axis == "x"
    assert plan.split_at_mm == 2000
