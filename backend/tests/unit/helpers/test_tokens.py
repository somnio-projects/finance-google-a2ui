import pytest

from app.helpers.tokens import extract_bearer, fingerprint


@pytest.mark.parametrize(
    ("header", "expected"),
    [
        ("Bearer abc.def", "abc.def"),
        ("bearer abc", "abc"),
        ("BEARER   spaced  ", "spaced"),
        ("Basic dXNlcg==", None),
        ("Bearer ", None),
        ("Bearer", None),
        ("", None),
        (None, None),
    ],
    ids=[
        "standard",
        "lowercase_scheme",
        "extra_spaces",
        "other_scheme",
        "empty_token",
        "scheme_only",
        "empty_header",
        "missing_header",
    ],
)
def test_extract_bearer_parses_rfc6750_header(
    header: str | None, expected: str | None
) -> None:
    assert extract_bearer(header) == expected


def test_fingerprint_is_stable_short_and_non_reversible() -> None:
    first = fingerprint("secret-token")
    assert first == fingerprint("secret-token")
    assert len(first) == 16
    assert "secret" not in first
    assert first != fingerprint("secret-token2")
