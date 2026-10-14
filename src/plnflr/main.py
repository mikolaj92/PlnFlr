"""PlnFlr FastAPI host on app-factory product shell."""

from __future__ import annotations

from contextlib import asynccontextmanager
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Annotated

import uvicorn
from app_factory.adapters import install_identity_adapters
from app_factory.platform import PlatformUser
from app_factory.responses import htmx_redirect
from app_factory.uploads import UploadLimitExceeded, read_upload_bounded
from fastapi import Depends, FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import ValidationError

from plnflr.forms import layout_form_from_request, layout_from_form
from plnflr.identity import require_identity
from plnflr.importing.roomplan import room_from_usdz
from plnflr.platform_chrome import PLATFORM_CONFIG, platform_config
from plnflr.render.svg import plan_to_svg
from plnflr.rooms import RoomStore, SavedRoom, default_form

PACKAGE_DIR = Path(__file__).parent
DATA_DIR = Path(__file__).resolve().parents[2] / "data"
ROOM_STORE = RoomStore(DATA_DIR / "rooms.json")
SCAN_MAX_BYTES = 8 * 1024 * 1024
templates = Jinja2Templates(directory=str(PACKAGE_DIR / "templates"))

@asynccontextmanager
async def lifespan(application: FastAPI):
    require_identity(application)
    yield


app = FastAPI(title="PlnFlr", docs_url=None, redoc_url=None, lifespan=lifespan)
# Compose kit chrome once; keep its mount before the product /static mount.
install_identity_adapters(
    app,
    environments=(templates.env,),
    config=PLATFORM_CONFIG,
    locales=lambda request: (PLATFORM_CONFIG.locales, PLATFORM_CONFIG.default_locale),
)
app.mount("/static", StaticFiles(directory=str(PACKAGE_DIR / "static")), name="static")


def _net_m2(area_mm2: int) -> str:
    return f"{(Decimal(area_mm2) / Decimal(1_000_000)).quantize(Decimal('0.001'))}"


def _room_user_id(request: Request) -> str:
    """Trust only the adapter's server-side session view, never request fields."""
    context = getattr(request.state, "app_factory_platform_context", {})
    user = context.get("platform_user")
    if (
        not isinstance(user, PlatformUser)
        or not isinstance(user.user_id, str)
        or not user.user_id.strip()
        or user.user_id == "local"
    ):
        login = PLATFORM_CONFIG.paths.href("login")
        raise HTTPException(
            status_code=303, headers={"Location": login, "HX-Redirect": login}
        )
    return user.user_id


RoomUserId = Annotated[str, Depends(_room_user_id)]


def _ctx(request: Request, rooms: list[SavedRoom] | None = None) -> dict:
    listed = rooms if rooms is not None else ROOM_STORE.list_for_user(_room_user_id(request))
    context = dict(request.state.app_factory_platform_context)
    context["platform_menu"] = platform_config(rooms=listed, current_path=request.url.path).menu
    context["lang"] = context["platform_locale"]
    return context


def _error_fragment(request: Request, message: str, status: int = 400) -> HTMLResponse:
    html = templates.get_template("partials/error.html").render(
        {**_ctx(request), "request": request, "error": message}
    )
    return HTMLResponse(html, status_code=status)


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"ok": "plnflr"}


@app.get("/")
def home(user_id: RoomUserId) -> RedirectResponse:
    room = ROOM_STORE.ensure_default(user_id)
    return RedirectResponse(f"/rooms/{room.id}", status_code=303)


@app.get("/rooms/new")
def new_room(request: Request, user_id: RoomUserId):
    rooms = ROOM_STORE.list_for_user(user_id)
    return templates.TemplateResponse(
        request,
        "new_room.html",
        {
            "request": request,
            "page_title": "Nowy pokój",
            "nav_active": "new-room",
            **_ctx(request, rooms),
        },
    )


@app.post("/rooms")
def create_room(user_id: RoomUserId, name: str = Form("")) -> RedirectResponse:
    room = ROOM_STORE.create(user_id, name)
    return RedirectResponse(f"/rooms/{room.id}", status_code=303)


@app.get("/rooms/{room_id}")
def show_room(request: Request, room_id: str, user_id: RoomUserId):
    rooms = ROOM_STORE.list_for_user(user_id)
    room = ROOM_STORE.get(room_id, user_id=user_id)
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
            "scan_max_bytes": SCAN_MAX_BYTES,
            **_ctx(request, rooms),
        },
    )


@app.post("/rooms/{room_id}/scan")
async def import_scan(
    request: Request,
    room_id: str,
    user_id: RoomUserId,
    scan: Annotated[UploadFile, File()],
):
    saved = ROOM_STORE.get(room_id, user_id=user_id)
    if saved is None:
        return htmx_redirect(request, "/")
    try:
        uploaded = await read_upload_bounded(scan, max_bytes=SCAN_MAX_BYTES)
        captured = room_from_usdz(uploaded.data)
    except UploadLimitExceeded:
        return _error_fragment(request, "Skan jest za duży.", status=413)
    except (ValueError, KeyError, OSError) as exc:
        return _error_fragment(request, str(exc) or "Nie da się wczytać skanu.")
    finally:
        await scan.close()
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
            "window_segments": captured.window_segments,
        }
    )
    ROOM_STORE.update_form(room_id, user_id=user_id, form=form)
    return htmx_redirect(request, f"/rooms/{saved.id}")


@app.post("/rooms/{room_id}/plan")
async def plan_room(request: Request, room_id: str, user_id: RoomUserId):
    saved = ROOM_STORE.get(room_id, user_id=user_id)
    if saved is None:
        return _error_fragment(request, "Nie ma takiego pokoju.", status=404)
    try:
        form = await layout_form_from_request(request)
        laid = layout_from_form(form)
    except (ValueError, ValidationError, InvalidOperation) as exc:
        return _error_fragment(request, str(exc) or "Niepoprawne wymiary.")
    ROOM_STORE.update_form(room_id, user_id=user_id, form=form.model_dump())
    svg = plan_to_svg(laid)
    html = templates.get_template("partials/plan.html").render(
        {
            **_ctx(request),
            "request": request,
            "plan": laid,
            "svg": svg,
            "net_m2": _net_m2(laid.bom.area_net_mm2),
            "error": None,
        }
    )
    return HTMLResponse(html)


@app.post("/plan")
async def plan_legacy(request: Request, user_id: RoomUserId):
    room = ROOM_STORE.ensure_default(user_id)
    return await plan_room(request, room.id, user_id)


def main() -> None:
    require_identity(app)
    uvicorn.run("plnflr.main:app", host="0.0.0.0", port=8004, reload=False)
