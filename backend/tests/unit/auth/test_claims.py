import pytest

from app.auth.claims import principal_from_claims
from app.core.errors import AuthenticationError


def test_principal_from_claims_maps_subject_email_and_scopes() -> None:
    principal = principal_from_claims(
        {"sub": "abc", "email": "a@b.test", "scope": "Read write"},
        provider="jwt",
        token="tok",
    )
    assert principal.subject == "abc"
    assert principal.email == "a@b.test"
    assert principal.scopes == frozenset({"read", "write"})
    assert principal.provider == "jwt"
    assert len(principal.token_fingerprint) == 16
    assert principal.has_scope("READ") is True
    assert principal.has_scope("admin") is False


@pytest.mark.parametrize(
    ("payload", "expected"),
    [
        ({"sub": "s", "scp": ["A", "b"]}, {"a", "b"}),
        ({"sub": "s", "roles": ["Admin"]}, {"admin"}),
        ({"sub": "s", "scope": ""}, set()),
        ({"sub": "s", "scope": 42}, set()),
        ({"sub": "s"}, set()),
    ],
    ids=["scp_list", "roles_list", "empty_scope", "non_string_scope", "no_scope"],
)
def test_principal_from_claims_collects_scopes_from_every_claim(
    payload: dict[str, object], expected: set[str]
) -> None:
    principal = principal_from_claims(payload, provider="jwt", token="tok")
    assert principal.scopes == frozenset(expected)


def test_principal_from_claims_ignores_non_string_email() -> None:
    principal = principal_from_claims({"sub": "s", "email": 5}, provider="p", token="t")
    assert principal.email is None


@pytest.mark.parametrize(
    "payload", [{}, {"sub": ""}, {"sub": 12}], ids=["missing", "empty", "not_str"]
)
def test_principal_from_claims_requires_subject(payload: dict[str, object]) -> None:
    with pytest.raises(AuthenticationError, match="subject claim"):
        principal_from_claims(payload, provider="p", token="t")


@pytest.mark.parametrize(
    ("amr", "expected"),
    [(["pwd", "MFA"], {"pwd", "mfa"}), ("pwd otp", {"pwd", "otp"}), (None, set())],
    ids=["list", "space_separated", "absent"],
)
def test_principal_from_claims_collects_authentication_methods(
    amr: object, expected: set[str]
) -> None:
    payload: dict[str, object] = {"sub": "s"}
    if amr is not None:
        payload["amr"] = amr
    principal = principal_from_claims(payload, provider="jwt", token="tok")
    assert principal.auth_methods == frozenset(expected)
