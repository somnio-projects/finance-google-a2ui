"""Spec 0058 AC-1 — ``usageMetadata`` is read when present and never breaks a call."""

import httpx
import pytest

from app.core.model_usage import ZERO_USAGE, TokenUsage
from app.infra.model.usage import usage_from, usage_of

#: The shape the Gemini API reference documents for ``generateContent``.
FULL = {
    "promptTokenCount": 4210,
    "cachedContentTokenCount": 1024,
    "candidatesTokenCount": 312,
    "thoughtsTokenCount": 488,
    "totalTokenCount": 5010,
}


def test_usage_from_reads_all_five_counts() -> None:
    assert usage_from({"candidates": [], "usageMetadata": FULL}) == TokenUsage(
        prompt=4210,
        cached=1024,
        candidates=312,
        thoughts=488,
        total=5010,
        billed_calls=1,
    )


def test_usage_from_treats_an_absent_count_as_zero() -> None:
    """A blocked prompt is billed for its input and reports nothing else."""
    usage = usage_from({"usageMetadata": {"promptTokenCount": 9}})

    assert usage == TokenUsage(prompt=9, billed_calls=1)


def test_usage_from_counts_an_empty_block_as_one_billed_call() -> None:
    assert usage_from({"usageMetadata": {}}) == TokenUsage(billed_calls=1)


@pytest.mark.parametrize(
    "payload",
    [
        {"candidates": []},
        ["not", "an", "object"],
        "text",
        None,
        {"usageMetadata": {"promptTokenCount": -3}},
        {"usageMetadata": {"promptTokenCount": "many"}},
        {"usageMetadata": "nope"},
    ],
    ids=[
        "no-block",
        "a-list",
        "a-string",
        "null",
        "negative",
        "not-a-number",
        "block-not-an-object",
    ],
)
def test_usage_from_anything_unreadable_is_zero_and_never_raises(
    payload: object,
) -> None:
    assert usage_from(payload) == ZERO_USAGE


def test_usage_of_reads_the_body_of_any_status() -> None:
    response = httpx.Response(500, json={"usageMetadata": {"promptTokenCount": 5}})

    assert usage_of(response) == TokenUsage(prompt=5, billed_calls=1)


def test_usage_of_a_body_that_is_not_json_is_zero() -> None:
    assert usage_of(httpx.Response(503, text="<html>down</html>")) == ZERO_USAGE
