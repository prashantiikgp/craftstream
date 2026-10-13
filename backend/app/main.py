"""CraftStream API: the app factory. Routes must match models/endpoints.yml (enforced by tests).

    uvicorn app.main:app          # settings from the environment / .env
    create_app(Settings(...))     # tests: fresh app with its own in-memory data
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.deps import Container, build_container
from app.api.routers import health, internal, orders, products, uploads
from app.core.errors import install_error_handlers
from app.core.logging import configure_logging
from app.core.settings import Settings, get_settings

API = "/api/v1"


def create_app(settings: Settings | None = None, container: Container | None = None) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(settings.mode, settings.log_level)

    app = FastAPI(title="CraftStream API", version="0.3.0")
    app.state.container = container or build_container(settings)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["Range"],  # the resumable uploader reads it from 308 responses
    )
    install_error_handlers(app)

    for router in (products.router, orders.router, uploads.router):
        app.include_router(router, prefix=API)
    app.include_router(internal.router)
    app.include_router(health.router)
    if settings.mode == "local":
        app.include_router(uploads.local_router)
    return app


app = create_app()
