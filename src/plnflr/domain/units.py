"""Parse metres from form input into integer millimetres."""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal


def metres_to_mm(value: str) -> int:
    metres = Decimal(value)
    if metres <= 0:
        raise ValueError("metres must be positive")
    millimetres = metres * 1000
    return int(millimetres.to_integral_value(rounding=ROUND_HALF_UP))


def mm_to_metres_str(millimetres: int) -> str:
    metres = Decimal(millimetres) / 1000
    return f"{metres:.3f}"
