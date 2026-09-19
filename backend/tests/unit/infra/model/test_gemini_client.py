"""Spec 0006 AC-2/AC-3/AC-4 — timeout, retries, masking and the key's one home.

Driven through ``httpx.MockTransport``: real httpx request building, real
status handling, no socket.
"""

import pytest

from app.core.errors import DependencyUnavailableError
from app.infra.model.gemini_client import UNAVAILABLE
from tests.unit.infra.model.gemini_stubs import (
    BASE_URL,
    KEY,
    PROVIDER_TEXT,
    Respond,
    Stub,
    make_client,
    no_candidates,
    not_json,
    ok,
    rate_limited,
    rejected,
    times_out,
    unauthorized,
    unavailable,
)


async def test_generate_returns_the_parsed_reply() -> None:
    stub = Stub(ok)

    reply = await make_client(stub).generate(system="rules", messages=[], tools=[])

    assert reply.text == "answer"
    assert len(stub.requests) == 1


async def test_generate_sends_the_key_in_a_header_and_never_in_the_url() -> None:
    stub = Stub(ok)

    await make_client(stub).generate(system="rules", messages=[], tools=[])

    request = stub.requests[0]
    assert request.headers["x-goog-api-key"] == KEY
    assert KEY not in str(request.url)
    assert str(request.url) == f"{BASE_URL}/models/gemini-test:generateContent"


@pytest.mark.parametrize(
    "responder", [unavailable, rate_limited], ids=["server_error", "rate_limited"]
)
async def test_generate_retries_a_retryable_status_up_to_the_attempt_cap(
    responder: Respond,
) -> None:
    stub = Stub(responder)

    with pytest.raises(DependencyUnavailableError, match=UNAVAILABLE):
        await make_client(stub).generate(system="rules", messages=[], tools=[])

    assert len(stub.requests) == 3


async def test_generate_stops_after_a_single_attempt_when_configured() -> None:
    stub = Stub(unavailable)

    with pytest.raises(DependencyUnavailableError, match=UNAVAILABLE):
        await make_client(stub, max_attempts=1).generate(
            system="rules", messages=[], tools=[]
        )

    assert len(stub.requests) == 1


async def test_generate_does_not_retry_a_non_retryable_status() -> None:
    stub = Stub(unauthorized)

    with pytest.raises(DependencyUnavailableError, match=UNAVAILABLE):
        await make_client(stub).generate(system="rules", messages=[], tools=[])

    assert len(stub.requests) == 1


async def test_generate_recovers_when_a_retry_succeeds() -> None:
    stub = Stub(unavailable, ok)

    reply = await make_client(stub).generate(system="rules", messages=[], tools=[])

    assert reply.text == "answer"
    assert len(stub.requests) == 2


async def test_generate_translates_a_timeout() -> None:
    stub = Stub(times_out)

    with pytest.raises(DependencyUnavailableError, match=UNAVAILABLE):
        await make_client(stub).generate(system="rules", messages=[], tools=[])

    assert len(stub.requests) == 3


async def test_generate_translates_a_body_that_is_not_json() -> None:
    stub = Stub(not_json)

    with pytest.raises(DependencyUnavailableError, match=UNAVAILABLE):
        await make_client(stub).generate(system="rules", messages=[], tools=[])

    assert len(stub.requests) == 1


async def test_generate_translates_a_malformed_reply() -> None:
    stub = Stub(no_candidates)

    with pytest.raises(DependencyUnavailableError, match=UNAVAILABLE):
        await make_client(stub).generate(system="rules", messages=[], tools=[])


async def test_provider_text_never_reaches_the_raised_error() -> None:
    stub = Stub(rejected)

    with pytest.raises(DependencyUnavailableError) as raised:
        await make_client(stub).generate(system="rules", messages=[], tools=[])

    assert str(raised.value) == UNAVAILABLE
    assert PROVIDER_TEXT not in str(raised.value)
    assert raised.value.__cause__ is not None
