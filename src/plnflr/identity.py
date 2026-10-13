"""Durable identity services and the shared fail-closed startup requirement."""

from collections.abc import Iterator, Mapping
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path

from fastapi import FastAPI
from my_auth import PasskeyConfig, PasskeyService, SQLiteChallengeStore
from my_auth.passkeys import SQLiteCredentialStore
from my_usermanager.adapters.my_auth_sqlite import SQLiteAuthDatabase
from my_usermanager.manager import UserManager


@dataclass(frozen=True, slots=True)
class IdentityServices:
    """Library services only; account and session policies remain host-owned."""

    database: SQLiteAuthDatabase
    manager: UserManager
    passkey: PasskeyService


@contextmanager
def identity_services(settings: Mapping[str, str]) -> Iterator[IdentityServices]:
    """Open the pinned libraries' durable stores, separate from RoomStore.

    Required settings: PLNFLR_IDENTITY_DATABASE (an absolute SQLite file),
    PLNFLR_PASSKEY_RP_ID, PLNFLR_PASSKEY_ORIGINS (comma-separated origins).
    This does not install routes, enable registration, or assign administrators.
    The host must keep this context open for the lifetime of its bindings.
    """
    names = (
        "PLNFLR_IDENTITY_DATABASE",
        "PLNFLR_PASSKEY_RP_ID",
        "PLNFLR_PASSKEY_ORIGINS",
    )
    missing = [name for name in names if not settings.get(name, "").strip()]
    if missing:
        raise ValueError("Missing identity settings: " + ", ".join(missing))
    path = Path(settings[names[0]])
    if not path.is_absolute() or path.name in {"rooms.json", ":memory:"}:
        raise ValueError("PLNFLR_IDENTITY_DATABASE must be an absolute, separate SQLite file")
    # Validate RP/origins using my-auth before opening or migrating any database.
    config = PasskeyConfig(
        rp_id=settings[names[1]],
        rp_name="PlnFlr",
        origins=tuple(origin.strip() for origin in settings[names[2]].split(",")),
    )
    database = SQLiteAuthDatabase(path)
    database.initialize()
    stores = database.stores()
    try:
        yield IdentityServices(
            database=database,
            manager=UserManager(users=stores.users, roles=stores.roles, grants=stores.grants),
            passkey=PasskeyService(
                config=config,
                challenges=SQLiteChallengeStore(path),
                credentials=SQLiteCredentialStore(path),
            ),
        )
    finally:
        stores.close()


def require_identity(app: FastAPI) -> None:
    """Use the same identity requirement for CLI and ASGI startup."""
    identity = getattr(app.state, "app_factory_identity", None)
    missing = [
        name
        for name in ("passkey_ui", "usermanager_ui")
        if getattr(identity, name, None) is None
    ]
    if missing:
        raise RuntimeError(
            "Python host identity is not configured: missing "
            + ", ".join(missing)
            + ". Both passkey and usermanager adapters are required. Configure "
            "durable account storage, session hooks and secret, "
            "registration/activation/recovery and administrator policies, "
            "and passkey RP ID/origins before starting the host."
        )
