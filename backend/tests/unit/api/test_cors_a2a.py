"""The browser's preflight to the agent surface (spec 0029 §2)."""

from fastapi.testclient import TestClient


def test_the_a2a_preflight_admits_every_header_the_client_sends(
    client: TestClient,
) -> None:
    """Spec 0029 §2 — the browser's preflight to `/` must be a 200.

    `X-A2A-Extensions` is sent on every turn; while it was absent from the
    allow-list the preflight was a 400 and the Assistant could not reach the
    agent, a defect `curl` — which never preflights — could not show.
    """
    response = client.options(
        "/",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": (
                "accept,authorization,content-type,x-a2a-extensions"
            ),
        },
    )
    assert response.status_code == 200
    allowed = response.headers["access-control-allow-headers"].lower()
    assert "x-a2a-extensions" in allowed
