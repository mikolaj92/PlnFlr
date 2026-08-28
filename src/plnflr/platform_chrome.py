"""Product shell chrome: paths, menu, and per-request platform context."""

from __future__ import annotations

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


def platform_config() -> PlatformConfig:
    return PlatformConfig(
        app_name=APP_NAME,
        brand_href="/",
        brand_htmx=False,
        navigation_label="Nawigacja",
        menu=(
            MenuGroup(
                "Produkt",
                (MenuItem(label="Planer", href="/", icon="layers"),),
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


def platform_request_context(*, current_path: str = "") -> dict[str, Any]:
    return build_platform_context(
        PLATFORM_CONFIG,
        user=None,
        current_path=current_path,
        locales=_LOCALES,
        locale=DEFAULT_LOCALE,
    )
