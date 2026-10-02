"""Spec 0053 §3, AC-2, AC-8 — the v1.0 card and catalog over HTTP.

The v1.0 card is public for the v0.9 card's reason; the catalog needs a token
and serves the checked-in bytes. The v0.9 card beside them must not move.
"""

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.container import Container
from app.presentation.a2ui_v1.wire import CATALOG_ID, CATALOG_PATH, EXTENSION_URI
from tests.a2ui_v1_schemas import errors
from tests.unit.api.a2a_envelopes import AUTH
from tests.unit.presentation.conftest import committed

CARD = "/a2ui/v1/.well-known/agent-card.json"
CATALOG = "/a2ui/v1/catalog"


def test_the_v1_card_is_readable_without_a_token(client: TestClient) -> None:
    response = client.get(CARD)

    assert response.status_code == 200
    card = response.json()
    assert card["protocolVersion"] == "1.0"
    assert card["url"].endswith("/a2ui/v1/a2a")


def test_the_v1_card_advertises_the_extension_and_the_catalog(
    client: TestClient,
) -> None:
    (extension,) = client.get(CARD).json()["capabilities"]["extensions"]

    assert extension["uri"] == EXTENSION_URI
    assert extension["required"] is False
    assert extension["params"]["supportedCatalogIds"] == [CATALOG_ID]
    assert errors("agent_capabilities.json", {"v1.0": extension["params"]}) == []


def test_the_v1_card_is_the_v0_9_agent_on_another_url(
    app: FastAPI, client: TestClient
) -> None:
    card = client.get(CARD).json()
    container: Container = app.state.container

    assert card["name"] == container.agent.card.name
    assert [skill["id"] for skill in card["skills"]] == list(
        container.agent.tools.names()
    )


def test_the_v0_9_card_still_speaks_v0_9(client: TestClient) -> None:
    """AC-8 — the v1.0 card is a second document, never an edit of the first."""
    card = client.get("/.well-known/agent-card.json").json()

    assert card["protocolVersion"] == "0.9"
    assert "extensions" not in card["capabilities"]


def test_the_catalog_needs_a_token(client: TestClient) -> None:
    response = client.get(CATALOG)

    assert response.status_code == 401
    assert response.json()["type"].endswith("auth/missing-token")


def test_the_catalog_serves_the_checked_in_bytes(client: TestClient) -> None:
    response = client.get(CATALOG, headers=AUTH)

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("application/json")
    assert response.text == committed(CATALOG_PATH)


def test_the_catalog_carries_a_strong_etag(client: TestClient) -> None:
    response = client.get(CATALOG, headers=AUTH)

    assert response.headers["etag"].startswith('"')
    assert response.headers["cache-control"] == "private, no-cache"


def test_a_matching_etag_answers_304_with_no_body(client: TestClient) -> None:
    etag = client.get(CATALOG, headers=AUTH).headers["etag"]

    response = client.get(CATALOG, headers={**AUTH, "If-None-Match": etag})

    assert response.status_code == 304
    assert response.content == b""
