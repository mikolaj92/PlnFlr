# PlnFlr

Plan ułożenia podłogi. Z obrysu pomieszczenia (prostokąt, L, dowolny wielokąt z otworami) i wymiaru deski albo kafelka liczy dylatację, siatkę, docinki, BOM i pokazuje całą instalację.

Stack: FastAPI + Jinja + HTMX + Alpine + Basecoat via [`app-factory`](https://github.com/mikolaj92/app-factory) `v0.6.22`.

## Run

```bash
uv sync --group dev
uv run plnflr
# http://127.0.0.1:8004
# live: https://plnflr.patryk.it
uv run pytest
```

v0.1: lista pokoi jednego otwartego użytkownika. User podaje obrys, kąt i ewentualną podziałkę (np. pół kafelki, pół panele); serwer liczy dylatację, siatkę, docinki, BOM i kolejność. Bez 3D i kont.

## Live

LaunchAgent `dev.plnflr.api` on mini-m4-0 (`0.0.0.0:8004`). Caddy CT109 reverse-proxies `plnflr.patryk.it`. After merge to `main`, restart the unit:

```bash
launchctl kickstart -k "gui/$(id -u)/dev.plnflr.api"
curl -fsS http://127.0.0.1:8004/healthz
```
