from plnflr.engine.grid import split_rows


def test_sliver_is_redistributed() -> None:
    rows = split_rows(inner_mm=2980, plank_width_mm=156, min_row_width_mm=50)
    assert sum(rows) == 2980
    assert all(r >= 50 for r in rows)
    assert abs(rows[0] - rows[-1]) <= 1


def test_exact_fit_all_full() -> None:
    rows = split_rows(1560, 156, 50)
    assert rows == (156,) * 10
