"""Every error leaves the API as an ErrorResponse (models/error_response.yml).

Services raise DomainError subclasses and know nothing about HTTP. The status of each code and the default
messages come from api/http.yml (http_engine); this is the only place that applies them.
"""

from __future__ import annotations

import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.domain.api import http_engine
from app.generated.models import ErrorResponse

log = logging.getLogger(__name__)


class DomainError(Exception):
    code = "bad_request"

    def __init__(self, message: str, *, code: str | None = None, details: list[str] | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.code = code or self.code
        self.details = details or []


class UnreadableVideo(Exception):
    """The uploaded file is not a video we can measure (wrong format, corrupt or empty)."""


class NotFound(DomainError):
    code = "not_found"


class Conflict(DomainError):
    """The request is valid but the current state doesn't allow it (e.g. ordering before the video is ready)."""

    code = "conflict"


class Unauthorized(DomainError):
    code = "unauthorized"


def _response(status: int, code: str, message: str, details: list[str] | None = None) -> JSONResponse:
    body = ErrorResponse(code=code, message=message, details=details or [])
    return JSONResponse(status_code=status, content=body.model_dump())


def install_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(DomainError)
    async def _domain(_: Request, exc: DomainError) -> JSONResponse:
        status = http_engine.status_for(exc.code, type(exc).code)
        return _response(status, exc.code, exc.message, exc.details)

    @app.exception_handler(StarletteHTTPException)
    async def _http(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        return _response(exc.status_code, http_engine.code_for_status(exc.status_code), str(exc.detail))

    @app.exception_handler(RequestValidationError)
    async def _validation(_: Request, exc: RequestValidationError) -> JSONResponse:
        details = [f"{'.'.join(str(p) for p in e['loc'])} - {e['msg']}" for e in exc.errors()]
        err = http_engine.validation_error()
        return _response(http_engine.status_for(err.code), err.code, err.message, details)

    @app.exception_handler(Exception)
    async def _unexpected(request: Request, exc: Exception) -> JSONResponse:
        log.exception("unhandled error", extra={"path": request.url.path})
        err = http_engine.internal_error()
        return _response(http_engine.status_for(err.code), err.code, err.message)
