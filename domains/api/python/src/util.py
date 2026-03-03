"""Shared utility helpers for the Python API service."""

from __future__ import annotations

import time


def health_response(service: str = "api-python") -> dict[str, object]:
    """Return a standard health-check payload."""
    return {"status": "ok", "service": service, "timestamp": int(time.time())}


def version_info() -> dict[str, str]:
    """Return version metadata."""
    return {"version": "1.0.0", "language": "python"}
