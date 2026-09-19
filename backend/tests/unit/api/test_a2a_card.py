"""Spec 0010 AC-1 — the agent card, the one public route on this surface."""

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.container import Container

CARD_URL = "/.well-known/agent-card.json"


def test_the_agent_card_is_readable_without_a_token(client: TestClient) -> None:
    """AC-1 — a client cannot hold a token before it has read this."""
    response = client.get(CARD_URL)

    assert response.status_code == 200
    assert response.json()["protocolVersion"] == "0.9"


def test_the_card_advertises_the_public_url_not_the_bind_address(
    client: TestClient,
) -> None:
    """ADR-D D-7 — the sample advertised 0.0.0.0, which no client can reach."""
    card = client.get(CARD_URL).json()

    bind_address = ".".join(["0"] * 4)

    assert card["url"].startswith("http")
    assert bind_address not in card["url"]


def test_the_card_advertises_one_skill_per_registered_tool(
    app: FastAPI, client: TestClient
) -> None:
    card = client.get(CARD_URL).json()
    container: Container = app.state.container

    assert [skill["id"] for skill in card["skills"]] == list(
        container.agent.tools.names()
    )
