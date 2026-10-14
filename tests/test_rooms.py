from app_factory.adapters.session import install_platform_request_context
from app_factory.platform import PlatformUser
from fastapi.testclient import TestClient

from plnflr.main import app
from plnflr.platform_chrome import PLATFORM_CONFIG
from plnflr.rooms import RoomStore, default_form


def test_home_redirects_to_default_room(tmp_path, monkeypatch) -> None:
    store = RoomStore(tmp_path / "rooms.json")
    monkeypatch.setattr("plnflr.main.ROOM_STORE", store)
    with TestClient(app, follow_redirects=False) as client:
        response = client.get("/")
    assert response.status_code == 303
    assert response.headers["location"].startswith("/rooms/")


def test_two_rooms_are_independent(tmp_path, monkeypatch) -> None:
    store = RoomStore(tmp_path / "rooms.json")
    first = store.create(user_id="test-account", name="Salon")
    second = store.create(
        user_id="second-account",
        name="Kuchnia",
        form={"width_m": "5.500", "height_m": "2.400"},
    )
    assert store.list_for_user(first.user_id) == [first]
    assert store.list_for_user(second.user_id) == [second]
    assert store.get(second.id, user_id=first.user_id) is None
    assert store.get(first.id, user_id=second.user_id) is None
    assert store.ensure_default(first.user_id) == first
    assert store.ensure_default(second.user_id) == second
    seeded = store.ensure_default("third-account")
    assert seeded.user_id == "third-account"
    assert store.ensure_default("third-account") == seeded
    assert store.list_for_user("third-account") == [seeded]
    assert store.list_for_user(first.user_id) == [first]
    assert store.list_for_user(second.user_id) == [second]

    monkeypatch.setattr("plnflr.main.ROOM_STORE", store)
    # Opaque cookies resolve through the adapter's server-side session lookup.
    sessions = {
        "session-a": PlatformUser(display_name="A", user_id=first.user_id),
        "session-b": PlatformUser(display_name="B", user_id=second.user_id),
    }
    monkeypatch.setattr(app, "user_middleware", [])
    monkeypatch.setattr(app, "middleware_stack", None)
    install_platform_request_context(
        app,
        config=PLATFORM_CONFIG,
        current_user=lambda request: sessions.get(request.cookies.get("session")),
    )
    with TestClient(app) as client_a, TestClient(app) as client_b:
        client_a.cookies.set("session", "session-a")
        client_b.cookies.set("session", "session-b")
        salon = client_a.get(f"/rooms/{first.id}")
        kuchnia = client_b.get(f"/rooms/{second.id}")
        for client, own, other in (
            (client_a, first, second), (client_b, second, first)
        ):
            listing = client.get("/rooms/new")
            assert listing.status_code == 200
            assert own.name in listing.text
            assert other.name not in listing.text
            denied = client.get(f"/rooms/{other.id}", follow_redirects=False)
            assert denied.status_code == 303
            assert denied.headers["location"] == "/"
            assert other.name not in denied.text
            plan = client.post(f"/rooms/{other.id}/plan", data=own.form)
            assert plan.status_code == 404
            assert "<svg" not in plan.text
            assert client.post(f"/rooms/{own.id}/plan", data=own.form).status_code == 200
    assert store.get(second.id, user_id=second.user_id).form["width_m"] == "5.500"
    assert salon.status_code == 200
    assert "Salon" in salon.text
    assert "Kuchnia" not in salon.text
    assert 'value="4.000"' in salon.text
    assert kuchnia.status_code == 200
    assert "Kuchnia" in kuchnia.text
    assert "Salon" not in kuchnia.text
    assert 'value="5.500"' in kuchnia.text
    assert 'hx-post="/rooms/' + second.id + '/plan"' in kuchnia.text


def test_create_room_from_form(tmp_path, monkeypatch) -> None:
    store = RoomStore(tmp_path / "rooms.json")
    monkeypatch.setattr("plnflr.main.ROOM_STORE", store)
    with TestClient(app, follow_redirects=False) as client:
        response = client.post("/rooms", data={"name": "Łazienka"})
    assert response.status_code == 303
    location = response.headers["location"]
    assert location.startswith("/rooms/")
    created = store.get(location.rsplit("/", 1)[-1], user_id="test-account")
    assert created is not None
    assert created.name == "Łazienka"


def test_store_seeds_one_open_user_room(tmp_path) -> None:
    store = RoomStore(tmp_path / "rooms.json")
    rooms = store.list_for_user("local")
    assert len(rooms) == 1
    assert rooms[0].name == "Pokój 1"
    assert rooms[0].form == default_form()
