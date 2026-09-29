"""Spec 0012 AC-7, AC-8 — revalidation on the two view reads.

The helper's own rules are tested in ``test_caching.py``; what is asserted
here is that each read endpoint derives its tag from the right things —
(resource, view, options, ``as_of``) — and answers 304 for a caller that
already holds it.
"""

import uuid
from collections.abc import Iterator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.caching import CACHE_CONTROL, VARY
from app.core.config import Settings
from app.core.principal import Principal
from app.helpers.clock import FixedClock
from tests.conftest import FakeReporter
from tests.unit.api.conftest import make_views_client

ALLOCATION = "holdings.allocation.v1"
WATERFALL = "attribution.waterfall.v1"
VIEWS_URL = "/v1/portfolios/current/views"
CATALOG_URL = "/v1/views"
AUTH = {"Authorization": "Bearer good"}


@pytest.fixture
def other_views_client(
    api_settings: Settings, clock: FixedClock, reporter: FakeReporter
) -> Iterator[TestClient]:
    """A client for a *different* authenticated subject, same app settings."""
    other = Principal(
        subject=f"user-{uuid.uuid4()}",
        provider="fake",
        email=None,
        scopes=frozenset({"read"}),
        token_fingerprint="0123456789abcdef",  # gitleaks:allow - test fixture
    )
    yield from make_views_client(
        api_settings, principal=other, clock=clock, reporter=reporter
    )


def vary_directives(header: str) -> list[str]:
    """Return a ``Vary`` header as the list RFC 9110 §12.5.5 says it is.

    **Read as a list rather than compared as a string**, because this client
    goes through the whole application and any middleware in it may add a
    directive of its own. Starlette 1.7.0 began appending ``Origin`` from the
    CORS middleware — correct, since a CORS response does vary by origin — and
    an equality assertion here turned a routine dependency bump red for a
    reason that had nothing to do with caching (PR #154).

    `tests/unit/api/test_caching.py` keeps its equality on purpose: it drives
    `ConditionalResponse` against a bare `Response` with no middleware, and
    there *"this helper writes exactly `Authorization`"* is the claim.

    Takes the header rather than the response: the test client's response
    type is `httpx2`'s, not `httpx`'s, and a helper that named either would be
    coupled to which one the transport happens to vendor.
    """
    return [directive.strip() for directive in header.split(",")]


def test_a_view_read_carries_a_strong_etag_and_a_cache_policy(
    views_client: TestClient,
) -> None:
    response = views_client.get(f"{VIEWS_URL}?view={ALLOCATION}", headers=AUTH)

    assert response.status_code == 200
    assert response.headers["ETag"].startswith('"')
    assert response.headers["Cache-Control"] == CACHE_CONTROL
    assert VARY in vary_directives(response.headers["Vary"])


def test_revalidating_a_view_read_answers_304_with_no_body(
    views_client: TestClient,
) -> None:
    """`as_of` is fixed per session, so the second read is byte-identical."""
    first = views_client.get(f"{VIEWS_URL}?view={ALLOCATION}", headers=AUTH)
    etag = first.headers["ETag"]

    second = views_client.get(
        f"{VIEWS_URL}?view={ALLOCATION}",
        headers={**AUTH, "If-None-Match": etag},
    )

    assert second.status_code == 304
    assert second.content == b""
    assert second.headers["ETag"] == etag
    assert VARY in vary_directives(second.headers["Vary"])


def test_a_different_option_is_a_different_entity(views_client: TestClient) -> None:
    """A tag blind to the options would serve the wrong precision from cache."""
    plain = views_client.get(f"{VIEWS_URL}?view={ALLOCATION}", headers=AUTH)
    trimmed = views_client.get(f"{VIEWS_URL}?view={ALLOCATION}&top_n=1", headers=AUTH)

    assert plain.headers["ETag"] != trimmed.headers["ETag"]

    stale = views_client.get(
        f"{VIEWS_URL}?view={ALLOCATION}&top_n=1",
        headers={**AUTH, "If-None-Match": plain.headers["ETag"]},
    )
    assert stale.status_code == 200


def test_two_subjects_never_share_a_portfolio_entity_tag(
    views_client: TestClient, other_views_client: TestClient
) -> None:
    """The subject is in the digest, so one caller's tag cannot match another's.

    Without it, a client or proxy keyed on the URL alone could revalidate one
    subject's portfolio against another's and be told 304.
    """
    mine = views_client.get(f"{VIEWS_URL}?view={ALLOCATION}", headers=AUTH)
    theirs = other_views_client.get(f"{VIEWS_URL}?view={ALLOCATION}", headers=AUTH)

    assert mine.headers["ETag"] != theirs.headers["ETag"]


def test_a_different_view_is_a_different_entity(views_client: TestClient) -> None:
    allocation = views_client.get(f"{VIEWS_URL}?view={ALLOCATION}", headers=AUTH)
    waterfall = views_client.get(f"{VIEWS_URL}?view={WATERFALL}", headers=AUTH)

    assert allocation.headers["ETag"] != waterfall.headers["ETag"]


def test_the_catalog_revalidates_too(views_client: TestClient) -> None:
    first = views_client.get(CATALOG_URL, headers=AUTH)
    etag = first.headers["ETag"]

    second = views_client.get(CATALOG_URL, headers={**AUTH, "If-None-Match": etag})

    assert first.headers["Cache-Control"] == CACHE_CONTROL
    assert second.status_code == 304
    assert second.content == b""


def test_both_reads_document_their_304(app: FastAPI) -> None:
    """Documenting the 304 is part of the contract, not an implementation note."""
    paths = app.openapi()["paths"]
    for path in ("/v1/portfolios/{portfolio_id}/views", CATALOG_URL):
        operation = paths[path]["get"]
        assert "304" in operation["responses"], f"{path} does not document a 304"
        names = {parameter["name"] for parameter in operation["parameters"]}
        assert "If-None-Match" in names, f"{path} does not document the validator"
