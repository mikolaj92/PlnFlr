"""Polish row-by-row install copy."""

from __future__ import annotations

from collections import defaultdict
from dataclasses import replace

from plnflr.domain.models import LayoutPlan, Piece


def instructions_for(pieces: tuple[Piece, ...], *, gap_mm: int, has_holes: bool) -> tuple[str, ...]:
    by_row: dict[int, list[Piece]] = defaultdict(list)
    for piece in pieces:
        by_row[piece.row_index].append(piece)
    lines = [f"Dylatacja {gap_mm} mm wokół obrysu" + (" i przeszkód." if has_holes else ".")]
    for row in sorted(by_row):
        row_pieces = sorted(by_row[row], key=lambda p: p.install_order)
        width = row_pieces[0].width_mm
        clips = sum(1 for p in row_pieces if p.kind in {"clip", "rip"})
        start = row_pieces[0].length_mm
        end = row_pieces[-1].length_mm
        note = ""
        if clips:
            note = " Przytnij do ściany / otworu."
        lines.append(
            f"Rząd {row + 1} (szer. {width} mm): start {start} mm → "
            f"{len(row_pieces)} szt. → koniec {end} mm.{note}"
        )
    return tuple(lines)


def attach(plan: LayoutPlan) -> LayoutPlan:
    return replace(
        plan,
        rows_instruction_pl=instructions_for(
            plan.pieces, gap_mm=plan.gap_mm, has_holes=bool(plan.room.holes)
        ),
    )
