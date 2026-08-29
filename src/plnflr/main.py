"""PlnFlr FastAPI host on app-factory product shell."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from pathlib import Path

import uvicorn
from app_factory.fastapi import install_app_factory_ui
from fastapi import FastAPI, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import ValidationError

from plnflr.forms import LayoutForm, layout_from_form
from plnflr.platform_chrome import install_platform_chrome, platform_request_context
from plnflr.render.svg import plan_to_svg
from plnflr.rooms import OPEN_USER_ID, RoomStore, SavedRoom, default_form

PACKAGE_DIR = Path(__file__).parent
DATA_DIR = Path(__file__).resolve().parents[2] / "data"
ROOM_STORE = RoomStore(DATA_DIR / "rooms.json")
templates = Jinja2Templates(directory=str(PACKAGE_DIR / "templates"))

app = FastAPI(title="PlnFlr", docs_url=None, redoc_url=None)
install_app_factory_ui(app, environments=(templates.env,))
app.mount("/static", StaticFiles(directory=str(PACKAGE_DIR / "static")), name="static")
install_platform_chrome([templates.env])


def _net_m2(area_mm2: int) -> str:
    return f"{(Decimal(area_mm2) / Decimal(1_000_000)).quantize(Decimal('0.001'))}"


def _ctx(path: str, rooms: list[SavedRoom] | None = None) -> dict:
    listed = rooms if rooms is not None else ROOM_STORE.list_for_user(OPEN_USER_ID)
    return platform_request_context(current_path=path, rooms=listed)


def _error_fragment(request: Request, message: str, status: int = 400) -> HTMLResponse:
    html = templates.get_template("partials/error.html").render(
        {**_ctx("/"), "request": request, "error": message}
    )
    return HTMLResponse(html, status_code=status)


def _layout_form(**fields: str) -> LayoutForm:
    defaults = default_form()
    defaults.update({key: value for key, value in fields.items() if value is not None})
    return LayoutForm(
        shape=defaults["shape"],  # type: ignore[arg-type]
        kind=defaults["kind"],  # type: ignore[arg-type]
        width_m=defaults["width_m"],
        height_m=defaults["height_m"],
        l_span_x_m=defaults["l_span_x_m"],
        l_span_y_m=defaults["l_span_y_m"],
        l_cutout_x_m=defaults["l_cutout_x_m"],
        l_cutout_y_m=defaults["l_cutout_y_m"],
        vertices=defaults["vertices"],
        plank_length_m=defaults["plank_length_m"],
        plank_width_m=defaults["plank_width_m"],
        boards_per_pack=defaults["boards_per_pack"],
        tile_length_m=defaults["tile_length_m"],
        tile_width_m=defaults["tile_width_m"],
        grout_mm=defaults["grout_mm"],
        expansion_mm=defaults["expansion_mm"],
        direction=defaults["direction"],  # type: ignore[arg-type]
        stagger=defaults["stagger"],  # type: ignore[arg-type]
        angle_deg=defaults.get("angle_deg", "0"),
        split=defaults.get("split", "none"),  # type: ignore[arg-type]
        split_at_m=defaults.get("split_at_m", ""),
        kind_b=defaults.get("kind_b", "tile"),  # type: ignore[arg-type]
    )


def _form_payload(
    *,
    shape: str,
    kind: str,
    width_m: str,
    height_m: str,
    l_span_x_m: str,
    l_span_y_m: str,
    l_cutout_x_m: str,
    l_cutout_y_m: str,
    vertices: str,
    plank_length_m: str,
    plank_width_m: str,
    boards_per_pack: str,
    tile_length_m: str,
    tile_width_m: str,
    grout_mm: str,
    expansion_mm: str,
    direction: str,
    stagger: str,
    angle_deg: str = "0",
    split: str = "none",
    split_at_m: str = "",
    kind_b: str = "tile",
) -> dict[str, str]:
    return {
        "shape": shape,
        "kind": kind,
        "width_m": width_m,
        "height_m": height_m,
        "l_span_x_m": l_span_x_m,
        "l_span_y_m": l_span_y_m,
        "l_cutout_x_m": l_cutout_x_m,
        "l_cutout_y_m": l_cutout_y_m,
        "vertices": vertices,
        "plank_length_m": plank_length_m,
        "plank_width_m": plank_width_m,
        "boards_per_pack": boards_per_pack,
        "tile_length_m": tile_length_m,
        "tile_width_m": tile_width_m,
        "grout_mm": grout_mm,
        "expansion_mm": expansion_mm,
        "direction": direction,
        "stagger": stagger,
        "angle_deg": angle_deg,
        "split": split,
        "split_at_m": split_at_m,
        "kind_b": kind_b,
    }


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"ok": "plnflr"}


@app.get("/")
def home() -> RedirectResponse:
    room = ROOM_STORE.ensure_default(OPEN_USER_ID)
    return RedirectResponse(f"/rooms/{room.id}", status_code=303)


@app.get("/rooms/new")
def new_room(request: Request):
    rooms = ROOM_STORE.list_for_user(OPEN_USER_ID)
    return templates.TemplateResponse(
        request,
        "new_room.html",
        {
            "request": request,
            "page_title": "Nowy pokój",
            "nav_active": "new-room",
            **_ctx("/rooms/new", rooms),
        },
    )


@app.post("/rooms")
def create_room(name: str = Form("")) -> RedirectResponse:
    room = ROOM_STORE.create(OPEN_USER_ID, name)
    return RedirectResponse(f"/rooms/{room.id}", status_code=303)


@app.get("/rooms/{room_id}")
def show_room(request: Request, room_id: str):
    rooms = ROOM_STORE.list_for_user(OPEN_USER_ID)
    room = ROOM_STORE.get(room_id, user_id=OPEN_USER_ID)
    if room is None:
        return RedirectResponse("/", status_code=303)
    form = default_form()
    form.update(room.form)
    return templates.TemplateResponse(
        request,
        "home.html",
        {
            "request": request,
            "page_title": room.name,
            "nav_active": room.id,
            "room": room,
            "form": form,
            **_ctx(f"/rooms/{room.id}", rooms),
        },
    )


@app.post("/rooms/{room_id}/plan")
def plan_room(
    request: Request,
    room_id: str,
    shape: str = Form("rect"),
    kind: str = Form("plank"),
    width_m: str = Form("4.000"),
    height_m: str = Form("3.000"),
    l_span_x_m: str = Form("6.000"),
    l_span_y_m: str = Form("4.000"),
    l_cutout_x_m: str = Form("2.500"),
    l_cutout_y_m: str = Form("2.000"),
    vertices: str = Form(""),
    plank_length_m: str = Form("1.383"),
    plank_width_m: str = Form("0.156"),
    boards_per_pack: str = Form("8"),
    tile_length_m: str = Form("0.600"),
    tile_width_m: str = Form("0.600"),
    grout_mm: str = Form("3"),
    expansion_mm: str = Form(""),
    direction: str = Form("along_long"),
    stagger: str = Form("third"),
    angle_deg: str = Form("0"),
    split: str = Form("none"),
    split_at_m: str = Form(""),
    kind_b: str = Form("tile"),
):
    saved = ROOM_STORE.get(room_id, user_id=OPEN_USER_ID)
    if saved is None:
        return _error_fragment(request, "Nie ma takiego pokoju.", status=404)
    payload = _form_payload(
        shape=shape,
        kind=kind,
        width_m=width_m,
        height_m=height_m,
        l_span_x_m=l_span_x_m,
        l_span_y_m=l_span_y_m,
        l_cutout_x_m=l_cutout_x_m,
        l_cutout_y_m=l_cutout_y_m,
        vertices=vertices,
        plank_length_m=plank_length_m,
        plank_width_m=plank_width_m,
        boards_per_pack=boards_per_pack,
        tile_length_m=tile_length_m,
        tile_width_m=tile_width_m,
        grout_mm=grout_mm,
        expansion_mm=expansion_mm,
        direction=direction,
        stagger=stagger,
        angle_deg=angle_deg,
        split=split,
        split_at_m=split_at_m,
        kind_b=kind_b,
    )
    try:
        form = _layout_form(**payload)
        laid = layout_from_form(form)
    except (ValueError, ValidationError, InvalidOperation) as exc:
        return _error_fragment(request, str(exc) or "Niepoprawne wymiary.")
    ROOM_STORE.update_form(room_id, user_id=OPEN_USER_ID, form=payload)
    svg = plan_to_svg(laid)
    html = templates.get_template("partials/plan.html").render(
        {
            **_ctx(f"/rooms/{saved.id}"),
            "request": request,
            "plan": laid,
            "svg": svg,
            "net_m2": _net_m2(laid.bom.area_net_mm2),
            "error": None,
        }
    )
    return HTMLResponse(html)


@app.post("/plan")
def plan_legacy(
    request: Request,
    shape: str = Form("rect"),
    kind: str = Form("plank"),
    width_m: str = Form("4.000"),
    height_m: str = Form("3.000"),
    l_span_x_m: str = Form("6.000"),
    l_span_y_m: str = Form("4.000"),
    l_cutout_x_m: str = Form("2.500"),
    l_cutout_y_m: str = Form("2.000"),
    vertices: str = Form(""),
    plank_length_m: str = Form("1.383"),
    plank_width_m: str = Form("0.156"),
    boards_per_pack: str = Form("8"),
    tile_length_m: str = Form("0.600"),
    tile_width_m: str = Form("0.600"),
    grout_mm: str = Form("3"),
    expansion_mm: str = Form(""),
    direction: str = Form("along_long"),
    stagger: str = Form("third"),
    angle_deg: str = Form("0"),
    split: str = Form("none"),
    split_at_m: str = Form(""),
    kind_b: str = Form("tile"),
):
    room = ROOM_STORE.ensure_default(OPEN_USER_ID)
    return plan_room(
        request,
        room.id,
        shape=shape,
        kind=kind,
        width_m=width_m,
        height_m=height_m,
        l_span_x_m=l_span_x_m,
        l_span_y_m=l_span_y_m,
        l_cutout_x_m=l_cutout_x_m,
        l_cutout_y_m=l_cutout_y_m,
        vertices=vertices,
        plank_length_m=plank_length_m,
        plank_width_m=plank_width_m,
        boards_per_pack=boards_per_pack,
        tile_length_m=tile_length_m,
        tile_width_m=tile_width_m,
        grout_mm=grout_mm,
        expansion_mm=expansion_mm,
        direction=direction,
        stagger=stagger,
        angle_deg=angle_deg,
        split=split,
        split_at_m=split_at_m,
        kind_b=kind_b,
    )


def main() -> None:
    uvicorn.run("plnflr.main:app", host="0.0.0.0", port=8004, reload=False)
