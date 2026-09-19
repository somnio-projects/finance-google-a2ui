from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.errors import NotFoundError
from tests.conftest import FakeReporter


def _add_probe_routes(app: FastAPI) -> None:
    async def not_found() -> None:
        raise NotFoundError("widget 7 not found")

    async def explode() -> None:
        raise RuntimeError("secret internal detail")

    app.add_api_route("/_test/not-found", not_found)
    app.add_api_route("/_test/explode", explode)


def test_app_error_becomes_problem_details(app: FastAPI) -> None:
    _add_probe_routes(app)
    with TestClient(app) as client:
        response = client.get("/_test/not-found")
    assert response.status_code == 404
    assert response.json() == {
        "type": "https://errors.finance-a2ui/not-found",
        "title": "Not Found",
        "status": 404,
        "detail": "widget 7 not found",
        "instance": "/_test/not-found",
        "request_id": response.headers["X-Request-ID"],
    }


def test_unhandled_exception_is_reported_and_masked(
    app: FastAPI, reporter: FakeReporter
) -> None:
    _add_probe_routes(app)
    with TestClient(app, raise_server_exceptions=False) as client:
        response = client.get("/_test/explode")
    assert response.status_code == 500
    body = response.json()
    assert body["type"].endswith("/internal")
    assert body["detail"] == "an unexpected error occurred"
    assert "secret internal detail" not in response.text
    assert len(reporter.exceptions) == 1
    assert isinstance(reporter.exceptions[0], RuntimeError)
