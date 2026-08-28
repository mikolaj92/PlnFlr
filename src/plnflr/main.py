"""PlnFlr FastAPI host on app-factory product shell."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from pathlib import Path

import uvicorn
from app_factory.fastapi import install_app_factory_ui
from fastapi import FastAPI, Form, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import ValidationError

from plnflr.engine.plank import layout_planks
from plnflr.engine.tile import layout_tiles
from plnflr.forms import (
    LayoutForm,
    plank_from_form,
    room_from_form,
    rules_from_form,
    tile_from_form,
)
from plnflr.platform_chrome import install_platform_chrome, platform_request_context
from plnflr.render.svg import plan_to_svg

PACKAGE_DIR = Path(__file__).parent
templates = Jinja2Templates(directory=str(PACKAGE_DIR / "templates"))

app = FastAPI(title="PlnFlr", docs_url=None, redoc_url=None)
install_app_factory_ui(app, environments=(templates.env,))
app.mount("/static", StaticFiles(directory=str(PACKAGE_DIR / "static")), name="static")
install_platform_chrome([templates.env])


def _net_m2(area_mm2: int) -> str:
    return f"{(Decimal(area_mm2) / Decimal(1_000_000)).quantize(Decimal('0.001'))}"


def _error_fragment(request: Request, message: str, status: int = 400) -> HTMLResponse:
    html = templates.get_template("partials/error.html").render(
        {**platform_request_context(current_path="/"), "request": request, "error": message}
    )
    return HTMLResponse(html, status_code=status)


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"ok": "plnflr"}


@app.get("/")
def home(request: Request):
    return templates.TemplateResponse(
        request,
        "home.html",
        {"request": request, **platform_request_context(current_path="/")},
    )


@app.post("/plan")
def plan(
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
):
    try:
        form = LayoutForm(
            shape=shape,  # type: ignore[arg-type]
            kind=kind,  # type: ignore[arg-type]
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
            direction=direction,  # type: ignore[arg-type]
            stagger=stagger,  # type: ignore[arg-type]
        )
        room = room_from_form(form)
        rules = rules_from_form(form)
        if form.kind == "tile":
            laid = layout_tiles(room, tile_from_form(form), rules)
        else:
            laid = layout_planks(room, plank_from_form(form), rules)
    except (ValueError, ValidationError, InvalidOperation) as exc:
        return _error_fragment(request, str(exc) or "Niepoprawne wymiary.")
    svg = plan_to_svg(laid)
    html = templates.get_template("partials/plan.html").render(
        {
            **platform_request_context(current_path="/"),
            "request": request,
            "plan": laid,
            "svg": svg,
            "net_m2": _net_m2(laid.bom.area_net_mm2),
            "error": None,
        }
    )
    return HTMLResponse(html)


def main() -> None:
    uvicorn.run("plnflr.main:app", host="0.0.0.0", port=8004, reload=False)
