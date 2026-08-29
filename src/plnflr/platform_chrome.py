"""Product shell chrome: paths, menu, and per-request platform context."""

from __future__ import annotations

from collections.abc import Sequence
from typing import Any, Final

from app_factory.platform import (
    MenuGroup,
    MenuItem,
    PlatformConfig,
    PlatformLocale,
    PlatformPaths,
    apply_platform_context,
    build_platform_context,
)
from jinja2 import Environment

from plnflr.rooms import SavedRoom

APP_NAME: Final = "PlnFlr"
DEFAULT_LOCALE: Final = "pl"

_PATHS: Final = PlatformPaths(
    login="/",
    logout="/",
    register="/",
    account="/",
    admin_users="/",
)

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


def platform_config(*, rooms: Sequence[SavedRoom] = ()) -> PlatformConfig:
    room_items = tuple(
        MenuItem(
            label=room.name,
            href=f"/rooms/{room.id}",
            icon=ICON_ROOM,
            key=room.id,
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


def install_platform_chrome(environments: list[Environment]) -> PlatformConfig:
    for environment in environments:
        apply_platform_context(environment, PLATFORM_CONFIG)
    return PLATFORM_CONFIG


def platform_request_context(
    *,
    current_path: str = "",
    rooms: Sequence[SavedRoom] = (),
) -> dict[str, Any]:
    ctx = build_platform_context(
        platform_config(rooms=rooms),
        user=None,
        current_path=current_path,
        locales=_LOCALES,
        locale=DEFAULT_LOCALE,
    )
    ctx["lang"] = DEFAULT_LOCALE
    return ctx
