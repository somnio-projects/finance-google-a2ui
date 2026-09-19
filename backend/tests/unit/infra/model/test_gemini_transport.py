"""Spec 0006 AC-4 — the HTTP client the adapter owns, and retry classification."""

import httpx
import pytest
from pydantic import SecretStr
from pytest_mock import MockerFixture

from app.infra.model import gemini_client as module
from app.infra.model.gemini_client import GeminiModelClient, is_retryable
from tests.unit.infra.model.gemini_stubs import BASE_URL, KEY, Stub, ok


async def test_the_client_it_owns_uses_the_configured_timeout_and_is_closed(
    mocker: MockerFixture,
) -> None:
    real = httpx.AsyncClient
    timeouts: list[object] = []
    created: list[httpx.AsyncClient] = []

    def factory(**kwargs: object) -> httpx.AsyncClient:
        timeouts.append(kwargs["timeout"])
        client = real(transport=httpx.MockTransport(Stub(ok)))
        created.append(client)
        return client

    mocker.patch.object(module.httpx, "AsyncClient", side_effect=factory)
    client = GeminiModelClient(
        api_key=SecretStr(KEY),
        model="gemini-test",
        # The trailing slash proves the URL is joined, not concatenated.
        base_url=f"{BASE_URL}/",
        timeout_seconds=7.5,
        max_attempts=1,
    )

    reply = await client.generate(system="rules", messages=[], tools=[])

    assert reply.text == "answer"
    assert timeouts == [7.5]
    assert created[0].is_closed


@pytest.mark.parametrize(
    ("exc", "expected"),
    [
        (httpx.ConnectError("down"), True),
        (ValueError("not json"), False),
    ],
    ids=["transport_error_is_retryable", "parse_error_is_not"],
)
def test_is_retryable_classifies_non_status_failures(
    exc: Exception, expected: bool
) -> None:
    assert is_retryable(exc) is expected
