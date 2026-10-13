"""Every error leaves the API as an ErrorResponse (models/error_response.yml)."""

from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.generated.models import ErrorResponse

_CODES = {
    400: "bad_request",
    401: "unauthorized",
    403: "forbidden",
    404: "not_found",
    405: "method_not_allowed",
    409: "conflict",
    415: "unsupported_media_type",
    422: "validation_error",
}


class DomainError(Exception):
    """Raised by services; mapped to an HTTP status here and nowhere else."""

    status = 400
    code = "bad_request"

    def __init__(self, message: str, details: list[str] | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.details = details or []


class NotFound(DomainError):
    status = 404
    code = "not_found"


def _response(status: int, code: str, message: str, details: list[str] | None = None) -> JSONResponse:
    body = ErrorResponse(code=code, message=message, details=details or [])
    return JSONResponse(status_code=status, content=body.model_dump())


def install_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(DomainError)
    async def _domain(_: Request, exc: DomainError) -> JSONResponse:
        return _response(exc.status, exc.code, exc.message, exc.details)

    @app.exception_handler(StarletteHTTPException)
    async def _http(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        return _response(exc.status_code, _CODES.get(exc.status_code, "error"), str(exc.detail))

    @app.exception_handler(RequestValidationError)
    async def _validation(_: Request, exc: RequestValidationError) -> JSONResponse:
        details = [f"{'.'.join(str(p) for p in e['loc'])} - {e['msg']}" for e in exc.errors()]
        return _response(422, "validation_error", "The request is not valid.", details)

    @app.exception_handler(Exception)
    async def _unexpected(_: Request, exc: Exception) -> JSONResponse:
        return _response(500, "internal_error", "Something went wrong on our side.")
