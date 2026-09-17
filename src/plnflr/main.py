"""PlnFlr FastAPI host on app-factory product shell."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Annotated

import uvicorn
from app_factory.fastapi import install_app_factory_ui
from fastapi import FastAPI, File, Form, Request, UploadFile
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import ValidationError

from plnflr.forms import layout_form_from_request, layout_from_form
from plnflr.importing.roomplan import room_from_usdz
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


@app.post("/rooms/{room_id}/scan")
async def import_scan(
    request: Request,
    room_id: str,
    scan: Annotated[UploadFile, File()],
):
    saved = ROOM_STORE.get(room_id, user_id=OPEN_USER_ID)
    if saved is None:
        return RedirectResponse("/", status_code=303)
    payload = await scan.read()
    try:
        captured = room_from_usdz(payload)
    except (ValueError, KeyError, OSError) as exc:
        return _error_fragment(request, str(exc) or "Nie da się wczytać skanu.")
    form = default_form()
    form.update(saved.form)
    form.update(
        {
            "shape": "polygon",
            "vertices": captured.vertices_m,
            "hole_rectangles": captured.hole_rectangles,
            "hole_vertices": "",
            "door_rectangles": "",
            "door_vertices": captured.door_vertices,
        }
    )
    ROOM_STORE.update_form(room_id, user_id=OPEN_USER_ID, form=form)
    return RedirectResponse(f"/rooms/{saved.id}", status_code=303)


@app.post("/rooms/{room_id}/plan")
async def plan_room(request: Request, room_id: str):
    saved = ROOM_STORE.get(room_id, user_id=OPEN_USER_ID)
    if saved is None:
        return _error_fragment(request, "Nie ma takiego pokoju.", status=404)
    try:
        form = await layout_form_from_request(request)
        laid = layout_from_form(form)
    except (ValueError, ValidationError, InvalidOperation) as exc:
        return _error_fragment(request, str(exc) or "Niepoprawne wymiary.")
    ROOM_STORE.update_form(room_id, user_id=OPEN_USER_ID, form=form.model_dump())
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
async def plan_legacy(request: Request):
    room = ROOM_STORE.ensure_default(OPEN_USER_ID)
    return await plan_room(request, room.id)


def main() -> None:
    uvicorn.run("plnflr.main:app", host="0.0.0.0", port=8004, reload=False)
