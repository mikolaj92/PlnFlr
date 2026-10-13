"""Product shell configuration: paths, locale, and room navigation."""

from __future__ import annotations

import re
from collections.abc import Sequence
from typing import Final

from app_factory.platform import (
    MenuGroup,
    MenuItem,
    PlatformConfig,
    PlatformLocale,
    PlatformPaths,
)

from plnflr.rooms import SavedRoom

APP_NAME: Final = "PlnFlr"
DEFAULT_LOCALE: Final = "pl"

# Use the pinned kit's lifecycle contract; handlers require identity bindings.
_PATHS: Final = PlatformPaths()

_LOCALES: Final = (PlatformLocale(code="pl", label="PL"),)

ICON_ROOM = (
    '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" '
    'fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" '
    'stroke-linejoin="round" aria-hidden="true"><path d="M3 10.5 12 3l9 7.5"/>'
    '<path d="M5 10v10h14V10"/></svg>'
)
ICON_ADD = (
    '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" '
    'fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" '
    'stroke-linejoin="round" aria-hidden="true"><path d="M12 5v14"/><path d="M5 12h14"/></svg>'
)


def platform_config(*, rooms: Sequence[SavedRoom] = (), current_path: str = "") -> PlatformConfig:
    if not isinstance(current_path, str):
        raise ValueError("current_path must be a string")
    room_ids: set[str] = set()
    for room in rooms:
        if (
            not isinstance(room.id, str)
            or not re.fullmatch(r"[A-Za-z0-9_-]+", room.id)
            or room.id == "new"
        ):
            raise ValueError("room id must be a non-empty URL-safe path segment other than 'new'")
        if room.id in room_ids:
            raise ValueError("room ids must be unique")
        room_ids.add(room.id)
        if not isinstance(room.name, str) or not room.name.strip():
            raise ValueError("room name must be a non-empty string")
    room_items = tuple(
        MenuItem(
            label=room.name,
            href=f"/rooms/{room.id}",
            icon=ICON_ROOM,
            key=room.id,
            active=(
                current_path == f"/rooms/{room.id}" or current_path.startswith(f"/rooms/{room.id}/")
            ),
            no_htmx=True,
        )
        for room in rooms
    )
    return PlatformConfig(
        app_name=APP_NAME,
        brand_href="/",
        brand_htmx=False,
        navigation_label="Nawigacja",
        menu=(
            MenuGroup("Pokoje", room_items),
            MenuGroup(
                "Akcje",
                (
                    MenuItem(
                        label="Nowy pokój",
                        href="/rooms/new",
                        icon=ICON_ADD,
                        key="new-room",
                        active=current_path == "/rooms/new",
                        no_htmx=True,
                    ),
                ),
            ),
        ),
        paths=_PATHS,
        enable_admin_users=False,
        show_register=False,
        locales=_LOCALES,
        default_locale=DEFAULT_LOCALE,
        htmx_nav=False,
    )


PLATFORM_CONFIG: Final = platform_config()
