"""Parse metres from form input into integer millimetres."""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal


def _parse_metres(value: str) -> Decimal:
    return Decimal(value)


def _to_mm(metres: Decimal) -> int:
    return int((metres * 1000).to_integral_value(rounding=ROUND_HALF_UP))


def metres_to_mm(value: str) -> int:
    metres = _parse_metres(value)
    if metres <= 0:
        raise ValueError("metres must be positive")
    return _to_mm(metres)


def metres_to_mm_coord(value: str) -> int:
    metres = _parse_metres(value)
    if metres < 0:
        raise ValueError("metres must be non-negative")
    return _to_mm(metres)


def mm_to_metres_str(millimetres: int) -> str:
    metres = Decimal(millimetres) / 1000
    return f"{metres:.3f}"
