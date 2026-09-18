import re
from inspect import signature
from pathlib import Path

from fastapi.testclient import TestClient

from plnflr.forms import LayoutForm, parse_vertices, room_from_form, rules_from_form
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


def _input_tag(html: str, input_id: str) -> str:
    match = re.search(rf"<input[^>]*\sid=\"{input_id}\"[^>]*>", html)
    assert match is not None, input_id
    return match.group(0)


def test_home_uses_range_sliders_for_bounded_numbers() -> None:
    with TestClient(app) as client:
        response = client.get("/")
    html = response.text
    angle = _input_tag(html, "angle_deg")
    grout = _input_tag(html, "grout_mm")
    pack = _input_tag(html, "boards_per_pack")
    expansion = _input_tag(html, "expansion_mm")
    width = _input_tag(html, "width_m")
    assert 'type="range"' in angle and 'min="0"' in angle and 'max="90"' in angle
    assert 'type="range"' in grout and 'min="1"' in grout and 'max="10"' in grout
    assert 'type="range"' in pack and 'min="4"' in pack and 'max="16"' in pack
    assert 'type="range"' in expansion and 'min="0"' in expansion and 'max="30"' in expansion
    assert 'type="range"' not in width
    assert 'id="expansion_auto"' in html


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


def test_parse_vertices_allows_origin() -> None:
    ring = parse_vertices("0,0\n4,0\n4,3\n0,3")
    assert [(v.x_mm, v.y_mm) for v in ring.vertices] == [
        (0, 0),
        (4000, 0),
        (4000, 3000),
        (0, 3000),
    ]


def test_plan_polygon_from_origin_returns_svg() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/plan",
            data={
                "shape": "polygon",
                "kind": "plank",
                "vertices": "0,0\n4,0\n4,3\n0,3",
                "plank_length_m": "1.383",
                "plank_width_m": "0.156",
            },
        )
    assert response.status_code == 200
    assert "<svg" in response.text
    assert "metres must be positive" not in response.text


def test_plan_bowtie_returns_400() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/plan",
            data={
                "shape": "polygon",
                "kind": "plank",
                "vertices": "1,1\n2,2\n2,1\n1,2",
                "plank_length_m": "1.383",
                "plank_width_m": "0.156",
            },
        )
    assert response.status_code == 400
    assert "self-intersecting" in response.text.lower() or "wielokąt" in response.text.lower()
    assert "metres must be positive" not in response.text
    assert "<svg" not in response.text


def test_plan_explicit_zero_expansion_is_no_gap() -> None:
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
                "expansion_mm": "0",
            },
        )
    assert response.status_code == 200
    assert "<svg" in response.text
    assert ">0 mm<" in response.text


def test_rules_from_form_accepts_zero_expansion() -> None:
    rules = rules_from_form(LayoutForm(expansion_mm="0"))
    assert rules.expansion_mm == 0
