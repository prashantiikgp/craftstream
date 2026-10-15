"""CraftStream API: the app factory. Routes are mounted from models/endpoints.yml (via app/generated/api.py): each
router registers its handlers by endpoint name and api/endpoints.py adds them with the YAML's method, path and
status. Title, CORS and compression come from api/http.yml; defaults and the log format from app/app.yml.

    uvicorn app.main:app          # settings from the environment / .env
    create_app(Settings(...))     # tests: fresh app with its own in-memory data
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

from app.api.deps import Container, build_container
from app.api.endpoints import mount
from app.api.routers import health, internal, logs, orders, products, uploads
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
    install_error_handlers(app, on_unhandled=lambda path, exc: app.state.container.activity.record(
        "unhandled_error", path=path, error=type(exc).__name__))  # the type only: messages may carry data

    mount(app, (products.endpoints, orders.endpoints, uploads.endpoints, logs.endpoints, internal.endpoints,
                health.endpoints), settings.mode)
    return app


app = create_app()
