"""Spec 0058 §3 — token usage adds up, and the errors that carry it stay masked."""

import pytest
from pydantic import ValidationError

from app.core.errors import DependencyUnavailableError
from app.core.model import ModelReply
from app.core.model_errors import (
    MASKED_DETAIL,
    MODEL_OUT_OF_CREDIT,
    MODEL_UNAVAILABLE,
    ModelOutOfCreditError,
    ModelProviderError,
)
from app.core.model_usage import ZERO_USAGE, TokenUsage


def test_token_usage_adds_field_by_field() -> None:
    one = TokenUsage(
        prompt=1, cached=2, candidates=3, thoughts=4, total=5, billed_calls=1
    )
    two = TokenUsage(prompt=10, cached=20, candidates=30, thoughts=40, total=50)

    assert one + two == TokenUsage(
        prompt=11, cached=22, candidates=33, thoughts=44, total=55, billed_calls=1
    )
    assert one + ZERO_USAGE == one


def test_token_usage_rejects_a_negative_count() -> None:
    with pytest.raises(ValidationError, match="greater than or equal to 0"):
        TokenUsage(prompt=-1)


def test_a_reply_spends_nothing_unless_told_otherwise() -> None:
    assert ModelReply(text="hi").usage == ZERO_USAGE


@pytest.mark.parametrize(
    ("error", "outcome"),
    [
        (ModelProviderError, MODEL_UNAVAILABLE),
        (ModelOutOfCreditError, MODEL_OUT_OF_CREDIT),
    ],
    ids=["unavailable", "out-of-credit"],
)
def test_a_model_error_is_the_same_masked_problem_whatever_its_outcome(
    error: type[ModelProviderError], outcome: str
) -> None:
    """0058 OD-4 — a caller is never told whether our account has money."""
    usage = TokenUsage(prompt=7, billed_calls=1)

    failure = error("model provider unavailable", usage=usage)

    assert isinstance(failure, DependencyUnavailableError)
    assert failure.status == DependencyUnavailableError.status
    assert failure.code == DependencyUnavailableError.code
    assert failure.detail == "model provider unavailable"
    assert failure.outcome == outcome
    assert failure.usage == usage


def test_a_model_error_spends_nothing_by_default() -> None:
    assert ModelProviderError().usage == ZERO_USAGE


@pytest.mark.parametrize(
    "error", [ModelProviderError, ModelOutOfCreditError], ids=["unavailable", "402"]
)
def test_a_model_error_without_a_detail_never_falls_back_to_its_docstring(
    error: type[ModelProviderError],
) -> None:
    """The docstrings name the cause; the detail a caller sees must not."""
    assert error().detail == MASKED_DETAIL
