"""Every test gets a fresh local-mode app with its own in-memory data (no shared state between tests)."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.api.deps import Container, build_container
from app.core.settings import Settings
from app.main import create_app


@pytest.fixture
def settings() -> Settings:
    return Settings(mode="local", _env_file=None)


@pytest.fixture
def container(settings: Settings) -> Container:
    return build_container(settings)


@pytest.fixture
def client(settings: Settings, container: Container) -> TestClient:
    return TestClient(create_app(settings, container))
