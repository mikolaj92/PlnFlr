from __future__ import annotations

import pytest

from plnflr.rooms import RoomStore


@pytest.fixture(autouse=True)
def isolated_room_store(tmp_path, monkeypatch) -> RoomStore:
    store = RoomStore(tmp_path / "rooms.json")
    monkeypatch.setattr("plnflr.main.ROOM_STORE", store)
    return store
