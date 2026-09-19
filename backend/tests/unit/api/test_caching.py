"""Spec 0012 AC-7 — the conditional-request helper, on its own.

The helper is what every future read endpoint will reuse, so the comparison
rules are pinned here rather than inferred from one route's behaviour: an
absent header, a wildcard, a list, a weak tag and a miss each get a test.
"""

import pytest
from fastapi import Response

from app.api.caching import (
    CACHE_CONTROL,
    VARY,
    ConditionalResponse,
    get_conditional_response,
    matches,
    strong_etag,
)

TAG = '"a-tag"'
OTHER = '"another-tag"'


def test_the_same_inputs_give_the_same_strong_tag() -> None:
    assert strong_etag("views", ["a"], {"precision": 2}) == strong_etag(
        "views", ["a"], {"precision": 2}
    )


@pytest.mark.parametrize(
    "parts",
    [
        ("views", ["b"], {"precision": 2}),
        ("views", ["a"], {"precision": 4}),
        ("catalog", ["a"], {"precision": 2}),
    ],
    ids=["different-view", "different-option", "different-resource"],
)
def test_any_input_changing_changes_the_tag(parts: tuple[object, ...]) -> None:
    """A tag that ignored one of its inputs would serve a stale body."""
    assert strong_etag(*parts) != strong_etag("views", ["a"], {"precision": 2})


def test_the_tag_is_quoted_and_strong() -> None:
    """RFC 9110 §8.8.3 — quoted, and no `W/` prefix since the bytes match."""
    tag = strong_etag("views")
    assert tag.startswith('"') and tag.endswith('"')
    assert not tag.startswith("W/")


@pytest.mark.parametrize(
    ("header", "expected"),
    [
        (None, False),
        ("*", True),
        (TAG, True),
        (f"{OTHER}, {TAG}", True),
        (f"W/{TAG}", True),
        (OTHER, False),
        ("", False),
    ],
    ids=[
        "absent",
        "wildcard",
        "exact",
        "one-of-a-list",
        "weak-form-of-ours",
        "different-tag",
        "empty",
    ],
)
def test_if_none_match_is_compared_per_rfc_9110(
    header: str | None, expected: bool
) -> None:
    assert matches(header, TAG) is expected


def test_a_caller_without_the_tag_gets_the_body_and_the_validators() -> None:
    response = Response()
    conditional = ConditionalResponse(response, None)

    body = conditional.resolve({"a": 1}, etag=TAG)

    assert body == {"a": 1}
    assert response.headers["ETag"] == TAG
    assert response.headers["Cache-Control"] == CACHE_CONTROL
    assert response.headers["Vary"] == VARY


def test_a_caller_that_already_has_the_tag_gets_an_empty_304() -> None:
    """The saving is the body; the validators still travel (RFC 9110 §15.4.5)."""
    conditional = ConditionalResponse(Response(), TAG)

    answer = conditional.resolve({"a": 1}, etag=TAG)

    assert isinstance(answer, Response)
    assert answer.status_code == 304
    assert answer.body == b""
    assert answer.headers["ETag"] == TAG
    assert answer.headers["Cache-Control"] == CACHE_CONTROL
    assert answer.headers["Vary"] == VARY


def test_the_policy_forbids_reuse_without_asking() -> None:
    """A `max-age` would keep a switched-off endpoint rendering client-side."""
    assert "no-cache" in CACHE_CONTROL
    assert "private" in CACHE_CONTROL
    assert "max-age" not in CACHE_CONTROL


def test_the_provider_binds_the_header_to_the_response() -> None:
    response = Response()

    conditional = get_conditional_response(response, TAG)

    assert isinstance(conditional.resolve({"a": 1}, etag=TAG), Response)
