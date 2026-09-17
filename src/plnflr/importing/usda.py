"""Minimal USDA reader for RoomPlan meshes. No pxr, no numpy."""

from __future__ import annotations

import re
from dataclasses import dataclass

_MATRIX = re.compile(
    r"matrix4d xformOp:transform = \(\s*"
    r"\(([^)]+)\),\s*\(([^)]+)\),\s*\(([^)]+)\),\s*\(([^)]+)\)\s*\)"
)
_POINTS = re.compile(r"point3f\[\] points = \[([^\]]+)\]")
_COUNTS = re.compile(r"int\[\] faceVertexCounts = \[([^\]]+)\]")
_INDICES = re.compile(r"int\[\] faceVertexIndices = \[([^\]]+)\]")
_CATEGORY = re.compile(r'string Category = "([^"]+)"')
_TRIPLE = re.compile(r"\(([^)]+)\)")
_INTS = re.compile(r"-?\d+")


@dataclass(frozen=True, slots=True)
class UsdaMesh:
    name: str
    category: str
    points: tuple[tuple[float, float, float], ...]
    counts: tuple[int, ...]
    indices: tuple[int, ...]
    matrix: tuple[tuple[float, float, float, float], ...]


def _floats(raw: str) -> tuple[float, ...]:
    return tuple(float(part.strip()) for part in raw.split(","))


def _ints(raw: str) -> tuple[int, ...]:
    return tuple(int(part) for part in _INTS.findall(raw))


def parse_usda_mesh(text: str, *, name: str) -> UsdaMesh:
    matrix_match = _MATRIX.search(text)
    points_match = _POINTS.search(text)
    if matrix_match is None or points_match is None:
        raise ValueError(f"USDZ nie ma siatki {name}")
    matrix = tuple(_floats(row) for row in matrix_match.groups())
    points = tuple(_floats(trip) for trip in _TRIPLE.findall(points_match.group(1)))
    counts_match = _COUNTS.search(text)
    indices_match = _INDICES.search(text)
    counts = _ints(counts_match.group(1)) if counts_match else ()
    indices = _ints(indices_match.group(1)) if indices_match else ()
    category_match = _CATEGORY.search(text)
    category = category_match.group(1) if category_match else name
    return UsdaMesh(
        name=name,
        category=category,
        points=points,
        counts=counts,
        indices=indices,
        matrix=matrix,
    )


def transform_point(
    point: tuple[float, float, float],
    matrix: tuple[tuple[float, float, float, float], ...],
) -> tuple[float, float, float]:
    x, y, z = point
    return (
        x * matrix[0][0] + y * matrix[1][0] + z * matrix[2][0] + matrix[3][0],
        x * matrix[0][1] + y * matrix[1][1] + z * matrix[2][1] + matrix[3][1],
        x * matrix[0][2] + y * matrix[1][2] + z * matrix[2][2] + matrix[3][2],
    )
