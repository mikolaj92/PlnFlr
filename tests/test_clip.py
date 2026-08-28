import pytest

from plnflr.engine.clip import (
    area_mm2,
    inset,
    intersect_rect,
    normalize_ring,
    orientation_ccw,
    validate_room,
)


def test_square_area() -> None:
    outer = ((0, 0), (4000, 0), (4000, 3000), (0, 3000))
    assert area_mm2(outer) == 4000 * 3000


def test_cw_is_normalized_to_ccw() -> None:
    cw = ((0, 0), (0, 3000), (4000, 3000), (4000, 0))
    assert orientation_ccw(normalize_ring(cw))


def test_inset_square() -> None:
    inner, holes = inset(((0, 0), (4000, 0), (4000, 3000), (0, 3000)), (), gap_mm=10)
    assert holes == ()
    xs = [p[0] for p in inner]
    ys = [p[1] for p in inner]
    assert min(xs) == 10 and max(xs) == 3990
    assert min(ys) == 10 and max(ys) == 2990


def test_rect_clip_inside_is_identity() -> None:
    room = ((0, 0), (4000, 0), (4000, 3000), (0, 3000))
    r = ((100, 100), (200, 100), (200, 150), (100, 150))
    out = intersect_rect(r, room, ())
    assert len(out) == 1


def test_rect_outside_empty() -> None:
    room = ((0, 0), (1000, 0), (1000, 1000), (0, 1000))
    r = ((2000, 2000), (2100, 2000), (2100, 2100), (2000, 2100))
    assert intersect_rect(r, room, ()) == ()


def test_self_intersecting_rejected() -> None:
    bowtie = ((0, 0), (100, 100), (100, 0), (0, 100))
    with pytest.raises(ValueError, match="self"):
        validate_room(bowtie, ())
