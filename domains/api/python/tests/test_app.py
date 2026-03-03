"""Pytest test suite for the Python API service."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from src.app import create_app
from src.util import health_response, version_info


@pytest.fixture()
def client() -> TestClient:
    return TestClient(create_app())


class TestHealth:
    def test_returns_200(self, client: TestClient) -> None:
        response = client.get("/health")
        assert response.status_code == 200

    def test_status_ok(self, client: TestClient) -> None:
        data = client.get("/health").json()
        assert data["status"] == "ok"

    def test_service_name(self, client: TestClient) -> None:
        data = client.get("/health").json()
        assert data["service"] == "api-python"

    def test_has_timestamp(self, client: TestClient) -> None:
        data = client.get("/health").json()
        assert isinstance(data["timestamp"], int)


class TestVersion:
    def test_returns_200(self, client: TestClient) -> None:
        assert client.get("/version").status_code == 200

    def test_version_field(self, client: TestClient) -> None:
        data = client.get("/version").json()
        assert data["version"] == "1.0.0"

    def test_language_field(self, client: TestClient) -> None:
        data = client.get("/version").json()
        assert data["language"] == "python"


class TestRoot:
    def test_returns_200(self, client: TestClient) -> None:
        assert client.get("/").status_code == 200

    def test_message(self, client: TestClient) -> None:
        data = client.get("/").json()
        assert "message" in data


class TestUtils:
    def test_health_response_structure(self) -> None:
        result = health_response("test-svc")
        assert result["status"] == "ok"
        assert result["service"] == "test-svc"
        assert isinstance(result["timestamp"], int)

    def test_version_info_structure(self) -> None:
        result = version_info()
        assert "version" in result
        assert "language" in result
