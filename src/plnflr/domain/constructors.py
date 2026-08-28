"""Room shortcuts. Rectangle and L are constructors of the same polygon type."""

from __future__ import annotations

from plnflr.domain.models import Ring, Room, Vertex


def rectangle(width_mm: int, height_mm: int) -> Room:
    if width_mm <= 0 or height_mm <= 0:
        raise ValueError("rectangle sides must be positive")
    return Room(
        Ring(
            (
                Vertex(0, 0),
                Vertex(width_mm, 0),
                Vertex(width_mm, height_mm),
                Vertex(0, height_mm),
            )
        )
    )


def l_shape(
    *,
    span_x_mm: int,
    span_y_mm: int,
    cutout_x_mm: int,
    cutout_y_mm: int,
) -> Room:
    if min(span_x_mm, span_y_mm, cutout_x_mm, cutout_y_mm) <= 0:
        raise ValueError("L-shape dimensions must be positive")
    if cutout_x_mm >= span_x_mm or cutout_y_mm >= span_y_mm:
        raise ValueError("cutout must be smaller than span")
    keep_x = span_x_mm - cutout_x_mm
    keep_y = span_y_mm - cutout_y_mm
    return Room(
        Ring(
            (
                Vertex(0, 0),
                Vertex(span_x_mm, 0),
                Vertex(span_x_mm, keep_y),
                Vertex(keep_x, keep_y),
                Vertex(keep_x, span_y_mm),
                Vertex(0, span_y_mm),
            )
        )
    )
