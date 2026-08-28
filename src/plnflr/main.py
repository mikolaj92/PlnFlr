"""PlnFlr FastAPI host on app-factory product shell."""

from __future__ import annotations

from pathlib import Path

import uvicorn
from app_factory.fastapi import install_app_factory_ui
from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from plnflr.platform_chrome import install_platform_chrome, platform_request_context

PACKAGE_DIR = Path(__file__).parent
templates = Jinja2Templates(directory=str(PACKAGE_DIR / "templates"))

app = FastAPI(title="PlnFlr", docs_url=None, redoc_url=None)
install_app_factory_ui(app, environments=(templates.env,))
app.mount("/static", StaticFiles(directory=str(PACKAGE_DIR / "static")), name="static")
install_platform_chrome([templates.env])


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


def main() -> None:
    uvicorn.run("plnflr.main:app", host="0.0.0.0", port=8004, reload=False)
