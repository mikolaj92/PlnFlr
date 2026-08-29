from plnflr.engine.rotate import rotate_points


def test_rotate_90_is_exact() -> None:
    points = ((0, 0), (1000, 0), (1000, 400), (0, 400))
    rotated = rotate_points(points, 90, origin=(0, 0))
    assert rotated == ((0, 0), (0, 1000), (-400, 1000), (-400, 0))


def test_rotate_0_is_identity() -> None:
    points = ((10, 20), (30, 40))
    assert rotate_points(points, 0, origin=(0, 0)) == points
