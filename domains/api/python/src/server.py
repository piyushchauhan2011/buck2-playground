"""Entry point — run with: python -m src.server"""

from __future__ import annotations

import os

import uvicorn

from .app import app

if __name__ == "__main__":
    host = os.getenv("HOST", "127.0.0.1")
    port = int(os.getenv("PORT", "8000"))
    # Python FastAPI service
    uvicorn.run(app, host=host, port=port)
