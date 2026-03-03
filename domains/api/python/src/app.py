"""FastAPI application factory."""

from __future__ import annotations

from fastapi import FastAPI

from .util import health_response, version_info


def create_app() -> FastAPI:
    app = FastAPI(title="API Python Service", version="1.0.0")

    @app.get("/health")
    async def health() -> dict[str, object]:
        return health_response()

    @app.get("/version")
    async def version() -> dict[str, str]:
        return version_info()

    @app.get("/")
    async def root() -> dict[str, str]:
        return {"message": "API Python Service"}

    return app


app = create_app()
