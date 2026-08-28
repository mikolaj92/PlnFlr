from fastapi.testclient import TestClient

from plnflr.main import app


def test_home_uses_platform_assets_not_cdn() -> None:
    with TestClient(app) as client:
        response = client.get("/")
    assert response.status_code == 200
    assert "/static/platform/" in response.text
    assert "cdn.jsdelivr.net" not in response.text
    assert "unpkg.com" not in response.text
    assert "PlnFlr" in response.text


def test_healthz() -> None:
    with TestClient(app) as client:
        response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"ok": "plnflr"}
