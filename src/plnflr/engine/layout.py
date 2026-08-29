"""Compose one or two material zones into a single floor plan."""

from __future__ import annotations

from dataclasses import replace
from typing import Literal

from plnflr.domain.models import (
    BillOfMaterials,
    LayoutPlan,
    LayoutRules,
    Room,
    Vertex,
    Warning,
    Zone,
)
from plnflr.engine.bom import waste_pct
from plnflr.engine.expansion import bbox
from plnflr.engine.plank import layout_planks
from plnflr.engine.split import split_room
from plnflr.engine.tile import layout_tiles


def layout_floor(
    room: Room,
    zones: tuple[Zone, ...],
    rules: LayoutRules,
    *,
    split_axis: Literal["x", "y"] | None = None,
    split_at_mm: int | None = None,
) -> LayoutPlan:
    if not zones:
        raise ValueError("potrzeba przynajmniej jednej strefy")
    if split_axis is None or len(zones) == 1:
        return _stamp(_layout_zone(room, zones[0], rules), 0)

    min_x, min_y, max_x, max_y = bbox(room)
    at = split_at_mm
    if at is None:
        at = (min_x + max_x) // 2 if split_axis == "x" else (min_y + max_y) // 2
    first, second = split_room(room, axis=split_axis, at_mm=at)
    plans: list[LayoutPlan] = []
    if first is not None:
        plans.append(_stamp(_layout_zone(first, zones[0], rules), 0))
    if second is not None and len(zones) > 1:
        plans.append(_stamp(_layout_zone(second, zones[1], rules), 1))
    if not plans:
        raise ValueError("podziałka nie zostawia pola do ułożenia")
    return _merge(room, tuple(plans), rules, split_axis, at)


def _layout_zone(room: Room, zone: Zone, rules: LayoutRules) -> LayoutPlan:
    angle = zone.angle_deg if zone.angle_deg is not None else rules.angle_deg
    zone_rules = replace(rules, angle_deg=angle)
    if zone.kind == "tile":
        if zone.tile is None:
            raise ValueError("strefa płytek nie ma wymiaru")
        plan = layout_tiles(room, zone.tile, zone_rules)
        label = zone.label or "Płytki"
        kind: Literal["plank", "tile"] = "tile"
    else:
        if zone.plank is None:
            raise ValueError("strefa paneli nie ma wymiaru")
        plan = layout_planks(room, zone.plank, zone_rules)
        label = zone.label or "Panele"
        kind = "plank"
    bom = replace(plan.bom, label=label, kind=kind)
    return replace(plan, bom=bom, boms=(bom,))


def _stamp(plan: LayoutPlan, zone_index: int) -> LayoutPlan:
    pieces = tuple(
        replace(piece, zone_index=zone_index, piece_id=f"z{zone_index}-{piece.piece_id}")
        for piece in plan.pieces
    )
    return replace(plan, pieces=pieces)


def _merge(
    room: Room,
    plans: tuple[LayoutPlan, ...],
    rules: LayoutRules,
    split_axis: Literal["x", "y"],
    split_at_mm: int,
) -> LayoutPlan:
    pieces = tuple(piece for plan in plans for piece in plan.pieces)
    boms = tuple(plan.bom for plan in plans)
    warnings: list[Warning] = []
    for plan in plans:
        warnings.extend(plan.warnings)
    net = sum(bom.area_net_mm2 for bom in boms)
    bought = sum(bom.area_bought_mm2 for bom in boms)
    mixed = BillOfMaterials(
        pieces=sum(bom.pieces for bom in boms),
        full_boards=sum(bom.full_boards for bom in boms),
        packs=None,
        area_net_mm2=net,
        area_bought_mm2=bought,
        waste_pct=waste_pct(bought, net),
        label="Razem",
        kind="mixed",
    )
    gap = plans[0].gap_mm
    inset = plans[0].inset
    min_x, min_y, max_x, max_y = bbox(room)
    if split_axis == "x":
        divider = (Vertex(split_at_mm, min_y), Vertex(split_at_mm, max_y))
        split_word = "pionową"
    else:
        divider = (Vertex(min_x, split_at_mm), Vertex(max_x, split_at_mm))
        split_word = "poziomą"
    labels = " / ".join(bom.label or bom.kind for bom in boms)
    angle = rules.angle_deg
    angle_note = f" Kąt {angle}°." if angle else ""
    rationale = (
        f"Podziałka {split_word} na {split_at_mm} mm: {labels}. "
        f"Dylatacja {gap} mm także na styku materiałów.{angle_note}"
    )
    lines = [f"Dylatacja {gap} mm wokół obrysu i na podziałce."]
    for plan in plans:
        label = plan.bom.label or "Strefa"
        lines.append(f"{label}:")
        lines.extend(line for line in plan.rows_instruction_pl if not line.startswith("Dylatacja"))
    return LayoutPlan(
        room=room,
        gap_mm=gap,
        inset=inset,
        direction=plans[0].direction,
        pieces=pieces,
        bom=mixed,
        warnings=tuple(warnings),
        rationale_pl=rationale,
        rows_instruction_pl=tuple(lines),
        angle_deg=angle,
        split_axis=split_axis,
        split_at_mm=split_at_mm,
        boms=boms,
        divider=divider,
    )
