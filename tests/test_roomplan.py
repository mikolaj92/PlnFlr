"""RoomPlan USDZ → floor ring, fireplace hole, door threshold."""

from __future__ import annotations

import io
import zipfile
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from plnflr.domain.models import Vertex
from plnflr.forms import LayoutForm, layout_from_form
from plnflr.importing.roomplan import room_from_usdz
from plnflr.main import app


def _usda_mesh(
    *, name: str, category: str, points: str, counts: str, indices: str, matrix: str
) -> str:
    return f"""#usda 1.0
(
    defaultPrim = "{name}"
    metersPerUnit = 1
    upAxis = "Y"
)

def Xform "{name}" (
    customData = {{
        string Category = "{category}"
        string UUID = "00000000-0000-0000-0000-000000000000"
    }}
    kind = "component"
)
{{
    def Mesh "{name}"
    {{
        int[] faceVertexCounts = [{counts}]
        int[] faceVertexIndices = [{indices}]
        point3f[] points = [{points}]
        matrix4d xformOp:transform = {matrix}
        uniform token[] xformOpOrder = ["xformOp:transform"]
    }}
}}
"""


def _floor_usda() -> str:
    # Local XY is the slab, local Z thickness. Transform maps local Z → world Y
    # so plan coordinates are world XZ = (local x, local y).
    points = (
        "(0, 0, 0), (4, 0, 0), (4, 3, 0), (0, 3, 0), "
        "(0, 0, -0.16), (4, 0, -0.16), (4, 3, -0.16), (0, 3, -0.16)"
    )
    return _usda_mesh(
        name="Floor0",
        category="Floor",
        points=points,
        counts="3, 3, 3, 3",
        indices="0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6",
        matrix="( (1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1) )",
    )


def _box_usda(
    *, name: str, category: str, hx: float, hy: float, hz: float, tx: float, ty: float, tz: float
) -> str:
    points = (
        f"({-hx}, {-hy}, {-hz}), ({hx}, {-hy}, {-hz}), ({hx}, {hy}, {-hz}), ({-hx}, {hy}, {-hz}), "
        f"({-hx}, {-hy}, {hz}), ({hx}, {-hy}, {hz}), ({hx}, {hy}, {hz}), ({-hx}, {hy}, {hz})"
    )
    return _usda_mesh(
        name=name,
        category=category,
        points=points,
        counts="3, 3",
        indices="0, 1, 2, 0, 2, 3",
        matrix=f"( (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), ({tx}, {ty}, {tz}, 1) )",
    )


def make_salon_usdz() -> bytes:
    root = """#usda 1.0
(
    defaultPrim = "Scan"
    metersPerUnit = 1
    upAxis = "Y"
)

def Xform "Scan" (
    kind = "assembly"
)
{
    def Xform "Section_grp" ( kind = "group" )
    {
        def Xform "livingRoom0" ( kind = "assembly" ) { }
    }
    def Xform "Mesh_grp" ( kind = "group" )
    {
        def Xform "Floor_grp" (
            kind = "group"
            prepend references = @./assets/Mesh/Floors/Floor0.usda@
        ) { }
        def Xform "Object_grp" ( kind = "group" )
        {
            def Xform "Fireplace_grp" (
                kind = "group"
                prepend references = @./assets/Mesh/Fireplace/Fireplace0.usda@
            ) { }
        }
        def Xform "Arch_grp" ( kind = "group" )
        {
            def Xform "Wall_0_grp" (
                kind = "group"
                prepend references = @./assets/Mesh/Walls/Wall0/Door0.usda@
            ) { }
            def Xform "Wall_1_grp" (
                kind = "group"
                prepend references = @./assets/Mesh/Walls/Wall1/Window0.usda@
            ) { }
        }
    }
}
"""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        zf.writestr("Scan.usda", root)
        zf.writestr("assets/Mesh/Floors/Floor0.usda", _floor_usda())
        zf.writestr(
            "assets/Mesh/Fireplace/Fireplace0.usda",
            _box_usda(
                name="Fireplace0",
                category="Fireplace",
                hx=0.3,
                hy=0.5,
                hz=0.4,
                tx=1.0,
                ty=0.5,
                tz=1.5,
            ),
        )
        zf.writestr(
            "assets/Mesh/Walls/Wall0/Door0.usda",
            _box_usda(
                name="Door0",
                category="Door(Isopen: False)",
                hx=0.45,
                hy=1.0,
                hz=0.04,
                tx=2.0,
                ty=1.0,
                tz=0.04,
            ),
        )
        zf.writestr(
            "assets/Mesh/Walls/Wall1/Window0.usda",
            _box_usda(
                name="Window0",
                category="Window",
                hx=0.5,
                hy=0.6,
                hz=0.04,
                tx=2.0,
                ty=1.0,
                tz=0.0,
            ),
        )
    return buf.getvalue()


def test_roomplan_floor_is_polygon_in_millimetres() -> None:
    captured = room_from_usdz(make_salon_usdz())

    assert captured.name == "Salon"
    verts = {(v.x_mm, v.y_mm) for v in captured.room.outer.vertices}
    assert verts == {(0, 0), (4000, 0), (4000, 3000), (0, 3000)}
    assert captured.room.outer.vertices[0] == Vertex(0, 0)


def test_roomplan_fireplace_is_a_hole() -> None:
    captured = room_from_usdz(make_salon_usdz())

    assert len(captured.room.holes) == 2
    fire = captured.room.holes[0]
    xs = [v.x_mm for v in fire.vertices]
    ys = [v.y_mm for v in fire.vertices]
    assert min(xs) == 700 and max(xs) == 1300
    assert min(ys) == 1100 and max(ys) == 1900


def test_roomplan_door_is_threshold_strip() -> None:
    captured = room_from_usdz(make_salon_usdz())

    assert len(captured.thresholds) == 1
    strip = captured.thresholds[0]
    assert strip.label == "listwa progowa"
    assert strip.length_mm == 900
    assert strip.width_mm == 80
    door_hole = captured.room.holes[1]
    xs = [v.x_mm for v in door_hole.vertices]
    ys = [v.y_mm for v in door_hole.vertices]
    assert min(xs) == 1550 and max(xs) == 2450
    assert min(ys) == 0 and max(ys) == 80


def test_roomplan_window_is_opening_not_hole() -> None:
    captured = room_from_usdz(make_salon_usdz())

    assert len(captured.windows) == 1
    window = captured.windows[0]
    assert window.label == "okno"
    xs = [window.start.x_mm, window.end.x_mm]
    ys = [window.start.y_mm, window.end.y_mm]
    assert min(xs) == 1500 and max(xs) == 2500
    assert min(ys) == 0 and max(ys) == 0
    assert all(hole is not window for hole in captured.room.holes)
    assert captured.window_segments


def test_roomplan_rejects_empty_zip() -> None:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        zf.writestr("readme.txt", "no")
    with pytest.raises(ValueError, match="RoomPlan"):
        room_from_usdz(buf.getvalue())


def test_room_page_uses_factory_file_upload(isolated_room_store) -> None:
    room = isolated_room_store.ensure_default("local")
    with TestClient(app) as client:
        response = client.get(f"/rooms/{room.id}")
    assert response.status_code == 200
    assert "data-app-file-upload" in response.text
    assert "app-dropzone" in response.text
    assert 'name="scan"' in response.text
    assert "data-max-bytes=" in response.text
    assert 'hx-encoding="multipart/form-data"' in response.text
    assert "__appFileUploadBooted" in response.text


def test_upload_usdz_fills_polygon_and_doors(isolated_room_store) -> None:
    room = isolated_room_store.ensure_default("local")
    with TestClient(app) as client:
        response = client.post(
            f"/rooms/{room.id}/scan",
            files={"scan": ("salon.usdz", make_salon_usdz(), "model/vnd.usdz+zip")},
            follow_redirects=True,
        )
    assert response.status_code == 200
    assert "0,0" in response.text
    assert "4.000,0" in response.text or "4.000,0.000" in response.text
    assert 'value="polygon"' in response.text or "shape === 'polygon'" in response.text
    saved = isolated_room_store.get(room.id, user_id="local")
    assert saved is not None
    assert saved.form["shape"] == "polygon"
    assert "0,0" in saved.form["vertices"]
    assert saved.form["door_vertices"]
    assert saved.form["door_rectangles"] == ""
    assert saved.form["hole_rectangles"]


def test_htmx_scan_redirects_full_page(isolated_room_store) -> None:
    room = isolated_room_store.ensure_default("local")
    with TestClient(app) as client:
        response = client.post(
            f"/rooms/{room.id}/scan",
            files={"scan": ("salon.usdz", make_salon_usdz(), "model/vnd.usdz+zip")},
            headers={"HX-Request": "true"},
            follow_redirects=False,
        )
    assert response.status_code == 303
    assert response.headers["HX-Redirect"] == f"/rooms/{room.id}"


def test_oversized_scan_is_rejected(isolated_room_store, monkeypatch) -> None:
    monkeypatch.setattr("plnflr.main.SCAN_MAX_BYTES", 64)
    room = isolated_room_store.ensure_default("local")
    with TestClient(app) as client:
        response = client.post(
            f"/rooms/{room.id}/scan",
            files={"scan": ("salon.usdz", make_salon_usdz(), "model/vnd.usdz+zip")},
        )
    assert response.status_code == 413
    saved = isolated_room_store.get(room.id, user_id="local")
    assert saved is not None
    assert saved.form["shape"] != "polygon"


_SCAN2 = Path("/Users/mini-m4-0/usdz/Scan 2.usdz")


@pytest.mark.skipif(not _SCAN2.exists(), reason="investment scan not on this machine")
def test_upload_scan2_keeps_material_and_cuts_doors(isolated_room_store) -> None:
    room = isolated_room_store.ensure_default("local")
    isolated_room_store.update_form(
        room.id, user_id="local", form={"angle_deg": "15", "kind": "plank"}
    )
    with TestClient(app) as client:
        response = client.post(
            f"/rooms/{room.id}/scan",
            files={"scan": ("Scan 2.usdz", _SCAN2.read_bytes(), "model/vnd.usdz+zip")},
            follow_redirects=True,
        )
        saved = isolated_room_store.get(room.id, user_id="local")
        assert saved is not None
        assert saved.form["shape"] == "polygon"
        assert saved.form["angle_deg"] == "15"
        assert len(saved.form["vertices"].splitlines()) == 15
        assert saved.form["door_vertices"].count("\n\n") == 2
        plan = client.post(f"/rooms/{room.id}/plan", data=saved.form)
    assert response.status_code == 200
    assert plan.status_code == 200
    assert "listwa progowa" in plan.text.lower()
    assert plan.text.lower().count("listwa progowa") == 3
    assert "pln-threshold" in plan.text


def test_plan_from_imported_doors_lists_threshold_strip(isolated_room_store) -> None:
    room = isolated_room_store.ensure_default("local")
    with TestClient(app) as client:
        client.post(
            f"/rooms/{room.id}/scan",
            files={"scan": ("salon.usdz", make_salon_usdz(), "model/vnd.usdz+zip")},
        )
        saved = isolated_room_store.get(room.id, user_id="local")
        assert saved is not None
        response = client.post(f"/rooms/{room.id}/plan", data=saved.form)
    assert response.status_code == 200
    assert "<svg" in response.text
    assert "listwa progowa" in response.text.lower()
    assert "pln-threshold" in response.text


def make_rotated_door_usdz() -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        zf.writestr("Scan.usda", """#usda 1.0
(
    defaultPrim = "Scan"
    metersPerUnit = 1
    upAxis = "Y"
)

def Xform "Scan" ( kind = "assembly" )
{
    def Xform "Section_grp" ( kind = "group" )
    {
        def Xform "livingRoom0" ( kind = "assembly" ) { }
    }
    def Xform "Mesh_grp" ( kind = "group" )
    {
        def Xform "Floor_grp" (
            kind = "group"
            prepend references = @./assets/Mesh/Floors/Floor0.usda@
        ) { }
        def Xform "Arch_grp" ( kind = "group" )
        {
            def Xform "Wall_0_grp" (
                kind = "group"
                prepend references = @./assets/Mesh/Walls/Wall0/Door0.usda@
            ) { }
        }
    }
}
""")
        zf.writestr("assets/Mesh/Floors/Floor0.usda", _floor_usda())
        c = s = 0.70710678
        zf.writestr(
            "assets/Mesh/Walls/Wall0/Door0.usda",
            _box_usda(
                name="Door0",
                category="Door(Isopen: False)",
                hx=0.45,
                hy=1.0,
                hz=0.04,
                tx=2.0,
                ty=1.0,
                tz=1.5,
            ).replace(
                "( (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), (2.0, 1.0, 1.5, 1) )",
                f"( ({c}, 0, {-s}, 0), (0, 1, 0, 0), ({s}, 0, {c}, 0), (2.0, 1.0, 1.5, 1) )",
            ),
        )
    return buf.getvalue()


def test_rotated_door_keeps_threshold_width_through_form() -> None:
    captured = room_from_usdz(make_rotated_door_usdz())
    assert captured.thresholds[0].width_mm == 80
    plan = layout_from_form(
        LayoutForm(
            shape="polygon",
            vertices=captured.vertices_m,
            door_vertices=captured.door_vertices,
            plank_length_m="1.383",
            plank_width_m="0.156",
        )
    )
    assert len(plan.thresholds) == 1
    assert abs(plan.thresholds[0].width_mm - 80) <= 1
    assert abs(plan.thresholds[0].length_mm - captured.thresholds[0].length_mm) <= 1
