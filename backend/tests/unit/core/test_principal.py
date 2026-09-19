import pytest

from app.core.principal import Principal


def _principal(methods: set[str]) -> Principal:
    return Principal(
        subject="s",
        provider="jwt",
        token_fingerprint="0123456789abcdef",  # gitleaks:allow
        auth_methods=frozenset(methods),
    )


@pytest.mark.parametrize(
    ("methods", "expected"),
    [({"pwd", "otp"}, True), ({"hwk"}, True), ({"pwd"}, False), (set(), False)],
    ids=["otp", "hardware_key", "password_only", "absent"],
)
def test_principal_is_mfa_requires_a_second_factor_method(
    methods: set[str], expected: bool
) -> None:
    assert _principal(methods).is_mfa is expected
