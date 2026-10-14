from __future__ import annotations

from collections.abc import Iterator
from unittest.mock import Mock

import pytest
from app_factory.adapters import PasskeyBinding, UserManagerBinding, install_identity_adapters
from app_factory.platform import PlatformUser
from fastapi import HTTPException
from my_auth.fastapi import PasskeyRouteHooks
from my_usermanager.adapters.fastapi_htmx.standard import StandardUserManagerUiHooks
from starlette.datastructures import State

from plnflr.identity import identity_services
from plnflr.main import app, templates
from plnflr.platform_chrome import PLATFORM_CONFIG
from plnflr.rooms import RoomStore


@pytest.fixture(autouse=True)
def isolated_room_store(tmp_path, monkeypatch) -> Iterator[RoomStore]:
    store = RoomStore(tmp_path / "rooms.json")
    monkeypatch.setattr("plnflr.main.ROOM_STORE", store)
    # Product route tests run as an authenticated account, not the legacy local owner.
    denied = Mock(side_effect=HTTPException(status_code=403))
    with identity_services({
        "PLNFLR_IDENTITY_DATABASE": str(tmp_path / "identity.sqlite"),
        "PLNFLR_PASSKEY_RP_ID": "testserver",
        "PLNFLR_PASSKEY_ORIGINS": "https://testserver",
    }) as services:
        monkeypatch.setattr(app, "user_middleware", list(app.user_middleware))
        monkeypatch.setattr(app, "middleware_stack", None)
        monkeypatch.setattr(app.router, "routes", list(app.router.routes))
        monkeypatch.setattr(app, "state", State(dict(app.state._state)))
        monkeypatch.delattr(app.state, "app_factory_identity")
        monkeypatch.delattr(app.state, "app_factory_identity_signature")
        install_identity_adapters(
            app,
            environments=(templates.env,),
            config=PLATFORM_CONFIG,
            current_user=lambda request: PlatformUser(
                display_name="Test account", user_id="test-account"
            ),
            passkey=PasskeyBinding(
                service=services.passkey,
                hooks=PasskeyRouteHooks(
                    get_session_user=lambda request: None,
                    prepare_registration=denied,
                    complete_registration=denied,
                    get_auth_user=lambda user_id: None,
                    login=denied,
                    logout=lambda response, request: None,
                    render_login=denied,
                    render_register=denied,
                ),
            ),
            usermanager=UserManagerBinding(
                hooks=StandardUserManagerUiHooks(
                    manager=services.manager,
                    current_user=lambda request: None,
                    require_admin=denied,
                ),
                admin_enabled=False,
            ),
        )
        yield store
