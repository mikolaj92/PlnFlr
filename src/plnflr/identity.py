"""Fail closed until the Python host has both identity adapters."""

from fastapi import FastAPI


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
