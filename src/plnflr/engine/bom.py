"""Bill of materials from a laid-out plan."""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal

from plnflr.domain.models import BillOfMaterials


def waste_pct(area_bought_mm2: int, area_net_mm2: int) -> str:
    if area_net_mm2 <= 0:
        return "0.0"
    ratio = (Decimal(area_bought_mm2 - area_net_mm2) * Decimal(100)) / Decimal(area_net_mm2)
    return str(ratio.quantize(Decimal("0.1"), rounding=ROUND_HALF_UP))


def make_bom(
    *,
    pieces: int,
    full_boards: int,
    boards_per_pack: int | None,
    area_net_mm2: int,
    board_area_mm2: int,
) -> BillOfMaterials:
    bought = full_boards * board_area_mm2
    packs = None
    if boards_per_pack and boards_per_pack > 0:
        packs = (full_boards + boards_per_pack - 1) // boards_per_pack
    return BillOfMaterials(
        pieces=pieces,
        full_boards=full_boards,
        packs=packs,
        area_net_mm2=area_net_mm2,
        area_bought_mm2=bought,
        waste_pct=waste_pct(bought, area_net_mm2),
    )
