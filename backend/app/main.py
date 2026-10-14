"""CraftStream API: the app factory. Routes must match models/endpoints.yml (enforced by tests); the base path
comes from it (via app/generated/api.py), and title, CORS and compression from api/http.yml.

    uvicorn app.main:app          # settings from the environment / .env
    create_app(Settings(...))     # tests: fresh app with its own in-memory data
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

from app.api.deps import Container, build_container
from app.api.routers import health, internal, orders, products, uploads
from app.core.errors import install_error_handlers
from app.core.logging import configure_logging
from app.core.settings import Settings, get_settings
from app.domain.api import http_engine
from app.generated.api import BASE_PATH

API = BASE_PATH


def create_app(settings: Settings | None = None, container: Container | None = None) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(settings.mode, settings.log_level)

    app = FastAPI(title=http_engine.title(), version=http_engine.version())
    app.state.container = container or build_container(settings)
    cors = http_engine.cors()
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_methods=list(cors.allow_methods),
        allow_headers=list(cors.allow_headers),
        expose_headers=list(cors.expose_headers),
    )
    app.add_middleware(GZipMiddleware, minimum_size=http_engine.gzip_minimum_bytes())
    install_error_handlers(app)

    for router in (products.router, orders.router, uploads.router):
        app.include_router(router, prefix=API)
    app.include_router(internal.router)
    app.include_router(health.router)
    if settings.mode == "local":
        app.include_router(uploads.local_router)
    return app


app = create_app()
