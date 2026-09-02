from inspect import signature
from pathlib import Path

from fastapi.testclient import TestClient

from plnflr.forms import LayoutForm, room_from_form
from plnflr.main import app, plan_legacy, plan_room


def test_plan_routes_do_not_duplicate_layout_field_parameters() -> None:
    assert list(signature(plan_room).parameters) == ["request", "room_id"]
    assert list(signature(plan_legacy).parameters) == ["request"]


def test_home_uses_platform_assets_not_cdn() -> None:
    with TestClient(app) as client:
        response = client.get("/")
    assert response.status_code == 200
    assert "/static/platform/" in response.text
    assert "cdn.jsdelivr.net" not in response.text
    assert "unpkg.com" not in response.text
    assert "PlnFlr" in response.text
    assert "Pokój 1" in response.text


def test_healthz() -> None:
    with TestClient(app) as client:
        response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"ok": "plnflr"}


def test_home_has_layout_form() -> None:
    with TestClient(app) as client:
        response = client.get("/")
    assert response.status_code == 200
    assert "Rozłóż podłogę" in response.text
    assert 'hx-post="/rooms/' in response.text
    assert 'name="angle_deg"' in response.text
    assert "Podziałka" in response.text
    assert 'name="hole_rectangles"' in response.text
    assert 'name="hole_vertices"' in response.text
    assert "Silnik rozkładu jest w kolejce" not in response.text


def test_product_templates_use_current_basecoat_card_contract() -> None:
    forbidden = (
        "card-header",
        "card-content",
        "btn-primary",
        "btn-secondary",
        "btn-destructive",
        "btn-ghost",
    )
    templates = Path(__file__).resolve().parents[1] / "src" / "plnflr" / "templates"
    rendered_sources = "\n".join(path.read_text() for path in templates.rglob("*.html"))
    assert all(marker not in rendered_sources for marker in forbidden)
    assert "<header>" in rendered_sources
    assert "<section>" in rendered_sources


def test_room_from_form_adds_rectangular_hole() -> None:
    room = room_from_form(
        LayoutForm(
            shape="rect",
            width_m="4",
            height_m="3",
            hole_rectangles="1,1,1,1",
        )
    )

    assert len(room.holes) == 1
    assert [(vertex.x_mm, vertex.y_mm) for vertex in room.holes[0].vertices] == [
        (1000, 1000),
        (2000, 1000),
        (2000, 2000),
        (1000, 2000),
    ]


def test_plan_rectangle_returns_svg_and_row() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/plan",
            data={
                "shape": "rect",
                "kind": "plank",
                "width_m": "4.000",
                "height_m": "3.000",
                "plank_length_m": "1.383",
                "plank_width_m": "0.156",
                "boards_per_pack": "8",
                "direction": "along_long",
                "stagger": "third",
            },
        )
    assert response.status_code == 200
    assert "<svg" in response.text
    assert "Rząd 1" in response.text
    assert "Paczek" in response.text


def test_plan_with_hole_excludes_hole_from_svg_and_bom() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/plan",
            data={
                "shape": "rect",
                "kind": "tile",
                "width_m": "4",
                "height_m": "3",
                "hole_rectangles": "1,1,1,1",
                "tile_length_m": "1",
                "tile_width_m": "1",
                "grout_mm": "1",
                "expansion_mm": "1",
            },
        )
    assert response.status_code == 200
    assert "<svg" in response.text
    assert "10.982 m²" in response.text
    assert "M 1000 1000 L 2000 1000 L 2000 2000 L 1000 2000 Z" in response.text


def test_plan_split_returns_two_zones() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/plan",
            data={
                "shape": "rect",
                "kind": "plank",
                "kind_b": "tile",
                "split": "x",
                "split_at_m": "2.000",
                "width_m": "4.000",
                "height_m": "3.000",
                "plank_length_m": "1.383",
                "plank_width_m": "0.156",
                "boards_per_pack": "8",
                "tile_length_m": "0.600",
                "tile_width_m": "0.600",
                "grout_mm": "3",
                "angle_deg": "0",
            },
        )
    assert response.status_code == 200
    assert "pln-divider" in response.text
    assert "Strefa A" in response.text
    assert "Strefa B" in response.text


def test_plan_l_shape_returns_svg() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/plan",
            data={
                "shape": "l",
                "kind": "plank",
                "l_span_x_m": "6.000",
                "l_span_y_m": "4.000",
                "l_cutout_x_m": "2.500",
                "l_cutout_y_m": "2.000",
                "plank_length_m": "1.383",
                "plank_width_m": "0.156",
            },
        )
    assert response.status_code == 200
    assert "<svg" in response.text
    assert "Rząd 1" in response.text


def test_plan_bowtie_returns_400() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/plan",
            data={
                "shape": "polygon",
                "kind": "plank",
                "vertices": "0,0\n1,1\n1,0\n0,1",
                "plank_length_m": "1.383",
                "plank_width_m": "0.156",
            },
        )
    assert response.status_code == 400
    assert "Nie da się rozłożyć" in response.text
