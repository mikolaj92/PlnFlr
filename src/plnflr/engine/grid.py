"""Axis-aligned rectangular grid on the inset bounding box."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal


@dataclass(frozen=True, slots=True)
class Slot:
    row_index: int
    x0: int
    y0: int
    x1: int
    y1: int
    kind: Literal["full", "start_cut", "end_cut", "rip"]


def split_rows(inner_mm: int, plank_width_mm: int, min_row_width_mm: int) -> tuple[int, ...]:
    if inner_mm <= 0 or plank_width_mm <= 0:
        raise ValueError("spans must be positive")
    n, rem = divmod(inner_mm, plank_width_mm)
    if n == 0:
        return (inner_mm,)
    if rem == 0:
        return (plank_width_mm,) * n
    if rem < min_row_width_mm:
        extra = plank_width_mm + rem
        first = extra // 2
        last = extra - first
        middle = n - 1
        if middle < 0:
            return (first, last) if last else (first,)
        return (first,) + (plank_width_mm,) * middle + (last,)
    return (plank_width_mm,) * n + (rem,)


def _row_lengths(
    inner_mm: int,
    plank_length_mm: int,
    start_cut_mm: int,
    min_end_mm: int,
) -> tuple[int, ...]:
    start = start_cut_mm
    if start <= 0 or start >= plank_length_mm:
        start = plank_length_mm
    remaining = inner_mm - start
    if remaining < 0:
        return (inner_mm,)
    lengths = [start]
    while remaining > 0:
        if remaining >= plank_length_mm:
            lengths.append(plank_length_mm)
            remaining -= plank_length_mm
        else:
            lengths.append(remaining)
            remaining = 0
    if len(lengths) >= 2 and lengths[-1] < min_end_mm:
        need = min_end_mm - lengths[-1]
        if lengths[0] - need >= min_end_mm:
            lengths[0] -= need
            lengths[-1] += need
        else:
            extra = lengths[0] + lengths[-1]
            lengths[0] = extra // 2
            lengths[-1] = extra - lengths[0]
            if len(lengths) == 2:
                return (lengths[0], lengths[-1])
    return tuple(lengths)


def iter_slots(
    *,
    min_x: int,
    min_y: int,
    max_x: int,
    max_y: int,
    plank_length_mm: int,
    plank_width_mm: int,
    min_row_width_mm: int,
    min_end_mm: int,
    stagger: Literal["third", "half"],
    direction: Literal["along_x", "along_y"],
) -> tuple[Slot, ...]:
    if direction == "along_x":
        along = max_x - min_x
        across = max_y - min_y
    else:
        along = max_y - min_y
        across = max_x - min_x
    rows = split_rows(across, plank_width_mm, min_row_width_mm)
    step = plank_length_mm // 3 if stagger == "third" else plank_length_mm // 2
    slots: list[Slot] = []
    offset = min_y if direction == "along_x" else min_x
    for row_index, width in enumerate(rows):
        start_cut = plank_length_mm
        if row_index:
            start_cut = plank_length_mm - ((row_index * step) % plank_length_mm)
            if start_cut < min_end_mm:
                start_cut = min_end_mm
            if start_cut > plank_length_mm - min_end_mm:
                start_cut = plank_length_mm
        lengths = _row_lengths(along, plank_length_mm, start_cut, min_end_mm)
        cursor = min_x if direction == "along_x" else min_y
        for col, length in enumerate(lengths):
            if col == 0 and length != plank_length_mm:
                piece_kind: Literal["full", "start_cut", "end_cut", "rip"] = "start_cut"
            elif col == len(lengths) - 1 and length != plank_length_mm:
                piece_kind = "end_cut"
            else:
                piece_kind = "full"
            if width != plank_width_mm:
                piece_kind = "rip"
            if direction == "along_x":
                slots.append(
                    Slot(row_index, cursor, offset, cursor + length, offset + width, piece_kind)
                )
            else:
                slots.append(
                    Slot(row_index, offset, cursor, offset + width, cursor + length, piece_kind)
                )
            cursor += length
        offset += width
    return tuple(slots)
