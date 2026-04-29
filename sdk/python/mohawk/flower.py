"""Convenience helpers for Flower + Mohawk local runs."""

from __future__ import annotations

from typing import Any, Optional


def start_flower_server(
    *,
    strategy: Optional[Any] = None,
    server_address: str = "0.0.0.0:8080",
    num_rounds: int = 1,
    config: Optional[Any] = None,
    **kwargs: Any,
) -> Any:
    """Start a Flower server with Mohawk-friendly defaults for quick smoke runs.

    Install the optional `flower` extra before using this helper.
    """

    try:
        from flwr.server import ServerConfig, start_server
    except Exception as exc:  # pragma: no cover - optional dependency path
        raise RuntimeError(
            "Flower dependency missing. Install with: pip install -e .[flower]"
        ) from exc

    resolved_config = (
        config if config is not None else ServerConfig(num_rounds=num_rounds)
    )
    return start_server(
        server_address=server_address,
        strategy=strategy,
        config=resolved_config,
        **kwargs,
    )
