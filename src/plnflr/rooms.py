"""Named rooms for the open user. Later each account gets its own list."""

from __future__ import annotations

import json
import uuid
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

OPEN_USER_ID = "local"


def default_form() -> dict[str, str]:
    return {
        "shape": "rect",
        "kind": "plank",
        "width_m": "4.000",
        "height_m": "3.000",
        "l_span_x_m": "6.000",
        "l_span_y_m": "4.000",
        "l_cutout_x_m": "2.500",
        "l_cutout_y_m": "2.000",
        "vertices": "0,0\n4,0\n4,2\n1.5,2\n1.5,3\n0,3",
        "plank_length_m": "1.383",
        "plank_width_m": "0.156",
        "boards_per_pack": "8",
        "tile_length_m": "0.600",
        "tile_width_m": "0.600",
        "grout_mm": "3",
        "expansion_mm": "",
        "direction": "along_long",
        "stagger": "third",
    }


def _now() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat()


@dataclass(slots=True)
class SavedRoom:
    id: str
    user_id: str
    name: str
    form: dict[str, str]
    created_at: str
    updated_at: str

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> SavedRoom:
        form = default_form()
        form.update({str(k): str(v) for k, v in dict(raw.get("form") or {}).items()})
        return cls(
            id=str(raw["id"]),
            user_id=str(raw["user_id"]),
            name=str(raw["name"]),
            form=form,
            created_at=str(raw.get("created_at") or _now()),
            updated_at=str(raw.get("updated_at") or _now()),
        )


class RoomStore:
    def __init__(self, path: Path) -> None:
        self.path = path

    def list_for_user(self, user_id: str) -> list[SavedRoom]:
        self._seed(user_id)
        return [room for room in self._load() if room.user_id == user_id]

    def get(self, room_id: str, *, user_id: str) -> SavedRoom | None:
        for room in self.list_for_user(user_id):
            if room.id == room_id:
                return room
        return None

    def create(
        self,
        user_id: str,
        name: str,
        form: dict[str, str] | None = None,
    ) -> SavedRoom:
        payload = default_form()
        if form:
            payload.update(form)
        stamp = _now()
        room = SavedRoom(
            id=uuid.uuid4().hex[:12],
            user_id=user_id,
            name=name.strip() or self._next_name(user_id),
            form=payload,
            created_at=stamp,
            updated_at=stamp,
        )
        rooms = self._load()
        rooms.append(room)
        self._save(rooms)
        return room

    def update_form(self, room_id: str, *, user_id: str, form: dict[str, str]) -> SavedRoom | None:
        rooms = self._load()
        updated: SavedRoom | None = None
        for index, room in enumerate(rooms):
            if room.id != room_id or room.user_id != user_id:
                continue
            merged = default_form()
            merged.update(room.form)
            merged.update(form)
            rooms[index] = SavedRoom(
                id=room.id,
                user_id=room.user_id,
                name=room.name,
                form=merged,
                created_at=room.created_at,
                updated_at=_now(),
            )
            updated = rooms[index]
            break
        if updated is not None:
            self._save(rooms)
        return updated

    def ensure_default(self, user_id: str) -> SavedRoom:
        rooms = self.list_for_user(user_id)
        return rooms[0]

    def _next_name(self, user_id: str) -> str:
        existing = [room for room in self._load() if room.user_id == user_id]
        return f"Pokój {len(existing) + 1}"

    def _seed(self, user_id: str) -> None:
        rooms = self._load()
        if any(room.user_id == user_id for room in rooms):
            return
        stamp = _now()
        rooms.append(
            SavedRoom(
                id=uuid.uuid4().hex[:12],
                user_id=user_id,
                name="Pokój 1",
                form=default_form(),
                created_at=stamp,
                updated_at=stamp,
            )
        )
        self._save(rooms)

    def _load(self) -> list[SavedRoom]:
        if not self.path.exists():
            return []
        raw = json.loads(self.path.read_text())
        return [SavedRoom.from_dict(item) for item in raw.get("rooms", [])]

    def _save(self, rooms: list[SavedRoom]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {"rooms": [asdict(room) for room in rooms]}
        self.path.write_text(json.dumps(payload, ensure_ascii=False, indent=2))
