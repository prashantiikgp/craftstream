"""Wiring: build repositories, gateways and services once per app, and hand them to routers.

`build_container` is the only place that looks at CRAFTSTREAM_MODE to choose GCP or local parts.
Tests pass their own Container to `create_app` to swap any part.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Annotated, Protocol

from fastapi import Depends, Header, Request

from app.core.errors import Unauthorized
from app.core.settings import Settings
from app.db.repositories.log_repo import FirestoreLogRepo, InMemoryLogRepo, LogRepo
from app.db.repositories.order_repo import FirestoreOrderRepo, InMemoryOrderRepo, OrderRepo
from app.db.repositories.product_repo import FirestoreProductRepo, InMemoryProductRepo, ProductRepo
from app.domain.catalog import listing_engine
from app.domain.catalog.catalog_service import CatalogService
from app.domain.media.media_service import MediaService, Storage, Transcoder
from app.domain.orders.order_service import OrderService
from app.domain.platform import activity_log_engine
from app.domain.platform.activity_log_service import ActivityLogService


class CallerVerifier(Protocol):
    def verify(self, authorization: str | None) -> str: ...


@dataclass
class Container:
    settings: Settings
    products: ProductRepo
    orders: OrderRepo
    storage: Storage
    transcoder: Transcoder
    callers: CallerVerifier
    logs: LogRepo = field(default_factory=InMemoryLogRepo)

    def __post_init__(self) -> None:
        self.activity = ActivityLogService(self.logs)
        self.catalog = CatalogService(self.products, self.activity)
        self.media = MediaService(self.products, self.storage, self.transcoder, self.activity)
        self.order_service = OrderService(self.products, self.orders, self.activity)


def build_container(settings: Settings) -> Container:
    if settings.mode == "gcp":
        from app.infra.gcp.auth import OidcCallerVerifier
        from app.infra.gcp.gcs import GcsStorage
        from app.infra.gcp.transcoder import GcpTranscoder

        return Container(
            settings=settings,
            products=FirestoreProductRepo(settings.gcp_project, listing_engine.products_collection(),
                                          listing_engine.search_candidate_limit()),
            orders=FirestoreOrderRepo(settings.gcp_project, listing_engine.orders_collection()),
            storage=GcsStorage(settings.gcp_project, settings.upload_bucket, settings.media_bucket),
            transcoder=GcpTranscoder(settings.gcp_project, settings.gcp_region,
                                     settings.upload_bucket, settings.media_bucket, settings.transcode_topic),
            callers=OidcCallerVerifier(settings.internal_audience_list, settings.internal_invoker_set),
            logs=FirestoreLogRepo(settings.gcp_project, activity_log_engine.collection(),
                                  activity_log_engine.expire_field(), activity_log_engine.write_timeout_seconds()),
        )
    from app.infra.local.local_auth import AllowAllCallers
    from app.infra.local.local_storage import LocalStorage
    from app.infra.local.local_transcoder import LocalTranscoder

    return Container(settings=settings, products=InMemoryProductRepo(), orders=InMemoryOrderRepo(),
                     storage=LocalStorage(), transcoder=LocalTranscoder(), callers=AllowAllCallers())


def get_container(request: Request) -> Container:
    return request.app.state.container


def get_catalog(c: Annotated[Container, Depends(get_container)]) -> CatalogService:
    return c.catalog


def get_media(c: Annotated[Container, Depends(get_container)]) -> MediaService:
    return c.media


def get_orders(c: Annotated[Container, Depends(get_container)]) -> OrderService:
    return c.order_service


def get_activity(c: Annotated[Container, Depends(get_container)]) -> ActivityLogService:
    return c.activity


def verify_internal_caller(request: Request, c: Annotated[Container, Depends(get_container)],
                           authorization: Annotated[str | None, Header()] = None) -> str:
    """Dependency for the internal routes: only our Eventarc trigger and Pub/Sub subscription get through."""
    from app.infra.gcp.auth import CallerRejected

    try:
        return c.callers.verify(authorization)
    except CallerRejected as e:
        # The reason only (never the token itself).
        c.activity.record("internal_call_rejected", path=request.url.path, reason=str(e))
        raise Unauthorized(str(e)) from e


CatalogDep = Annotated[CatalogService, Depends(get_catalog)]
MediaDep = Annotated[MediaService, Depends(get_media)]
OrdersDep = Annotated[OrderService, Depends(get_orders)]
ActivityDep = Annotated[ActivityLogService, Depends(get_activity)]
ContainerDep = Annotated[Container, Depends(get_container)]
