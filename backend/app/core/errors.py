"""Every error leaves the API as an ErrorResponse (models/error_response.yml).

Services raise DomainError subclasses and know nothing about HTTP; the status mapping lives here only.
"""

from __future__ import annotations

import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.generated.models import ErrorResponse

log = logging.getLogger(__name__)


class DomainError(Exception):
    code = "bad_request"

    def __init__(self, message: str, *, code: str | None = None, details: list[str] | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.code = code or self.code
        self.details = details or []


class NotFound(DomainError):
    code = "not_found"


class Conflict(DomainError):
    """The request is valid but the current state doesn't allow it (e.g. ordering before the video is ready)."""

    code = "conflict"


_STATUS_FOR = {NotFound: 404, Conflict: 409, DomainError: 400}

_CODE_FOR_STATUS = {
    400: "bad_request", 401: "unauthorized", 403: "forbidden", 404: "not_found", 405: "method_not_allowed",
    409: "conflict", 415: "unsupported_media_type", 422: "validation_error",
}


def _response(status: int, code: str, message: str, details: list[str] | None = None) -> JSONResponse:
    body = ErrorResponse(code=code, message=message, details=details or [])
    return JSONResponse(status_code=status, content=body.model_dump())


def install_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(DomainError)
    async def _domain(_: Request, exc: DomainError) -> JSONResponse:
        status = next(s for cls, s in _STATUS_FOR.items() if isinstance(exc, cls))
        return _response(status, exc.code, exc.message, exc.details)

    @app.exception_handler(StarletteHTTPException)
    async def _http(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        return _response(exc.status_code, _CODE_FOR_STATUS.get(exc.status_code, "error"), str(exc.detail))

    @app.exception_handler(RequestValidationError)
    async def _validation(_: Request, exc: RequestValidationError) -> JSONResponse:
        details = [f"{'.'.join(str(p) for p in e['loc'])} - {e['msg']}" for e in exc.errors()]
        return _response(422, "validation_error", "The request is not valid.", details)

    @app.exception_handler(Exception)
    async def _unexpected(request: Request, exc: Exception) -> JSONResponse:
        log.exception("unhandled error", extra={"path": request.url.path})
        return _response(500, "internal_error", "Something went wrong on our side.")
