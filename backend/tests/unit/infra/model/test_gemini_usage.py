"""Spec 0058 AC-2/AC-3/AC-10 — what a call cost, retries and failures included."""

import httpx
import pytest
import structlog

from app.core.model_errors import ModelOutOfCreditError, ModelProviderError
from app.core.model_usage import ZERO_USAGE, TokenUsage
from app.infra.model.gemini_client import UNAVAILABLE
from tests.unit.infra.model.gemini_stubs import (
    OK_BODY,
    Stub,
    make_client,
    ok,
    times_out,
    unavailable,
)

USAGE = {
    "promptTokenCount": 100,
    "cachedContentTokenCount": 40,
    "candidatesTokenCount": 7,
    "thoughtsTokenCount": 3,
    "totalTokenCount": 110,
}
BILLED = TokenUsage(
    prompt=100, cached=40, candidates=7, thoughts=3, total=110, billed_calls=1
)
#: What AI Studio answers once the prepaid balance is spent (2026-11-13).
OUT_OF_CREDIT_TEXT = "Your prepayment credits are depleted."


def billed_ok(request: httpx.Request) -> httpx.Response:
    """Answer a well-formed reply that reports its usage."""
    del request
    return httpx.Response(200, json={**OK_BODY, "usageMetadata": USAGE})


def billed_unavailable(request: httpx.Request) -> httpx.Response:
    """Answer a retryable 503 that still reports usage."""
    del request
    return httpx.Response(503, json={"usageMetadata": USAGE})


def billed_without_candidate(request: httpx.Request) -> httpx.Response:
    """Answer a blocked prompt: billed input, no candidate."""
    del request
    return httpx.Response(200, json={"usageMetadata": {"promptTokenCount": 50}})


def out_of_credit(request: httpx.Request) -> httpx.Response:
    """Answer 402, as AI Studio does once the balance reaches zero."""
    del request
    return httpx.Response(402, json={"error": {"message": OUT_OF_CREDIT_TEXT}})


async def test_generate_returns_the_usage_the_reply_reported() -> None:
    reply = await make_client(Stub(billed_ok)).generate(
        system="rules", messages=[], tools=[]
    )

    assert reply.text == "answer"
    assert reply.usage == BILLED


async def test_generate_without_usage_metadata_spends_nothing() -> None:
    reply = await make_client(Stub(ok)).generate(system="rules", messages=[], tools=[])

    assert reply.usage == ZERO_USAGE


async def test_generate_sums_usage_over_retried_attempts() -> None:
    """0058 OD-3 — a retried attempt Gemini says it billed is counted."""
    stub = Stub(billed_unavailable, unavailable, billed_ok)

    reply = await make_client(stub).generate(system="rules", messages=[], tools=[])

    assert len(stub.requests) == 3
    assert reply.usage == BILLED + BILLED


async def test_a_failed_call_carries_the_usage_its_attempts_billed() -> None:
    stub = Stub(billed_unavailable, times_out)

    with pytest.raises(ModelProviderError, match=UNAVAILABLE) as caught:
        await make_client(stub, max_attempts=2).generate(
            system="rules", messages=[], tools=[]
        )

    assert type(caught.value) is ModelProviderError
    assert caught.value.usage == BILLED


async def test_a_billed_reply_without_a_candidate_still_reports_its_cost() -> None:
    with pytest.raises(ModelProviderError, match=UNAVAILABLE) as caught:
        await make_client(Stub(billed_without_candidate)).generate(
            system="rules", messages=[], tools=[]
        )

    assert caught.value.usage == TokenUsage(prompt=50, billed_calls=1)


async def test_a_402_is_out_of_credit_is_not_retried_and_stays_masked() -> None:
    stub = Stub(out_of_credit)

    with structlog.testing.capture_logs() as logs:
        with pytest.raises(ModelOutOfCreditError, match=UNAVAILABLE) as caught:
            await make_client(stub).generate(system="rules", messages=[], tools=[])

    assert len(stub.requests) == 1
    assert caught.value.detail == UNAVAILABLE
    assert OUT_OF_CREDIT_TEXT not in str(caught.value)
    assert caught.value.usage == ZERO_USAGE
    # Masked outward, recorded inward (GGU-90 AC-4): the operator sees why.
    rejected = [entry for entry in logs if entry["event"] == "model_provider_rejected"]
    assert rejected[0]["status"] == 402
    assert OUT_OF_CREDIT_TEXT in rejected[0]["detail"]
