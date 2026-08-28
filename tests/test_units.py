import pytest

from plnflr.domain.units import metres_to_mm, mm_to_metres_str


def test_metres_to_mm_converts_whole_metres() -> None:
    assert metres_to_mm("4") == 4000


def test_metres_to_mm_rounds_half_up_to_nearest_millimetre() -> None:
    assert metres_to_mm("1.2345") == 1235


@pytest.mark.parametrize("value", ["0", "-1", "-0.001"])
def test_metres_to_mm_rejects_zero_and_negatives(value: str) -> None:
    with pytest.raises(ValueError):
        metres_to_mm(value)


def test_mm_to_metres_str_formats_three_decimal_places() -> None:
    assert mm_to_metres_str(4000) == "4.000"
