"""GENERATED FROM models/ BY tools/codegen.py. DO NOT EDIT BY HAND.

What the backend needs from models/endpoints.yml at run time (models/ is not in the server image): the base path
and every endpoint. app/api/endpoints.py mounts each router's handlers from ENDPOINTS by name.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class QueryParam:
    type: str                   # string | integer
    max_length: int | None = None
    minimum: int | None = None
    maximum: int | None = None


@dataclass(frozen=True)
class Endpoint:
    name: str
    method: str
    path: str                   # full path: public endpoints include BASE_PATH
    status: int                 # success status
    public: bool                # in the Dart client and /docs; internal endpoints are not
    summary: str = ""
    body: str | None = None     # request model (app/generated/models.py)
    returns: str | None = None  # response model
    mode: str | None = None     # mounted only in this CRAFTSTREAM_MODE; None = always
    query: dict[str, QueryParam] = field(default_factory=dict)


BASE_PATH = '/api/v1'

ENDPOINTS: dict[str, Endpoint] = {
    'createProduct': Endpoint(
        name='createProduct',
        method='POST',
        path='/api/v1/products',
        status=201,
        public=True,
        summary='Create a listing and get a resumable upload URL for its video.',
        body='ProductCreate',
        returns='UploadTicket',
    ),
    'listProducts': Endpoint(
        name='listProducts',
        method='GET',
        path='/api/v1/products',
        status=200,
        public=True,
        summary='Search and filter products whose video is ready, one page at a time.',
        returns='ProductPage',
        query={'q': QueryParam(type='string', max_length=200), 'tag': QueryParam(type='string', max_length=50), 'cursor': QueryParam(type='string', max_length=100), 'limit': QueryParam(type='integer', minimum=1)},
    ),
    'getProduct': Endpoint(
        name='getProduct',
        method='GET',
        path='/api/v1/products/{product_id}',
        status=200,
        public=True,
        summary='Product details with video status and HLS URL (poll this while the video processes).',
        returns='Product',
    ),
    'listTags': Endpoint(
        name='listTags',
        method='GET',
        path='/api/v1/tags',
        status=200,
        public=True,
        summary='Tags for the filter chips.',
        returns='TagList',
    ),
    'getUploadPolicy': Endpoint(
        name='getUploadPolicy',
        method='GET',
        path='/api/v1/upload-policy',
        status=200,
        public=True,
        summary='Limits to check on the device before uploading (15-min cap, file types, chunk size).',
        returns='UploadPolicy',
    ),
    'createOrder': Endpoint(
        name='createOrder',
        method='POST',
        path='/api/v1/orders',
        status=201,
        public=True,
        summary='Place an order. The flow ends here.',
        body='OrderCreate',
        returns='Order',
    ),
    'getOrder': Endpoint(
        name='getOrder',
        method='GET',
        path='/api/v1/orders/{order_id}',
        status=200,
        public=True,
        summary='One order, so a device can show its orders after a restart (it keeps only their ids).',
        returns='Order',
    ),
    'listLogs': Endpoint(
        name='listLogs',
        method='GET',
        path='/api/v1/logs',
        status=200,
        public=True,
        summary='The activity log, newest first, optionally narrowed to a group, level or listing.',
        returns='LogPage',
        query={'group': QueryParam(type='string', max_length=20), 'level': QueryParam(type='string', max_length=20), 'product_id': QueryParam(type='string', max_length=100), 'cursor': QueryParam(type='string', max_length=100), 'limit': QueryParam(type='integer', minimum=1)},
    ),
    'createLog': Endpoint(
        name='createLog',
        method='POST',
        path='/api/v1/logs',
        status=201,
        public=True,
        summary='The app reports an upload step only it sees (started, network dropped, resumed, finished, failed).',
        body='LogEntryCreate',
        returns='LogEntry',
    ),
    'health': Endpoint(
        name='health',
        method='GET',
        path='/health',
        status=200,
        public=False,
        summary="Liveness check for Cloud Run (not /healthz, which Google's front end reserves).",
    ),
    'localUpload': Endpoint(
        name='localUpload',
        method='PUT',
        path='/local-upload/{product_id}',
        status=200,
        public=False,
        summary='Local mode only. Fake GCS resumable upload target (Content-Range chunks, 308 until complete).',
        mode='local',
    ),
    'mediaUploaded': Endpoint(
        name='mediaUploaded',
        method='POST',
        path='/internal/media/uploaded',
        status=204,
        public=False,
        summary='Eventarc (GCS object finalized) -> start transcoding. OIDC-authenticated.',
    ),
    'mediaTranscoded': Endpoint(
        name='mediaTranscoded',
        method='POST',
        path='/internal/media/transcoded',
        status=204,
        public=False,
        summary='Pub/Sub push (Transcoder job finished) -> mark the video ready or failed. OIDC-authenticated.',
    ),
}
