from fastapi.testclient import TestClient

from plnflr.main import app
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
    first = store.create(user_id="local", name="Salon")
    second = store.create(
        user_id="local",
        name="Kuchnia",
        form={"width_m": "5.500", "height_m": "2.400"},
    )
    monkeypatch.setattr("plnflr.main.ROOM_STORE", store)
    with TestClient(app) as client:
        salon = client.get(f"/rooms/{first.id}")
        kuchnia = client.get(f"/rooms/{second.id}")
    assert salon.status_code == 200
    assert "Salon" in salon.text
    assert 'value="4.000"' in salon.text
    assert kuchnia.status_code == 200
    assert "Kuchnia" in kuchnia.text
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
    created = store.get(location.rsplit("/", 1)[-1], user_id="local")
    assert created is not None
    assert created.name == "Łazienka"


def test_store_seeds_one_open_user_room(tmp_path) -> None:
    store = RoomStore(tmp_path / "rooms.json")
    rooms = store.list_for_user("local")
    assert len(rooms) == 1
    assert rooms[0].name == "Pokój 1"
    assert rooms[0].form == default_form()
