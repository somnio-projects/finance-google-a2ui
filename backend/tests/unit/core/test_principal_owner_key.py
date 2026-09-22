"""Which portfolio a caller owns (spec 0035 OD-1, AC-2).

The defect this closes is not visible in one principal: it is that **two**
principals that are the same person must land on the same row. Firebase's
Google button and its e-mail button give one human two `sub` values, and
before 0035 that was two portfolios.
"""

import pytest

from app.core.principal import Principal


def _principal(*, subject: str, email: str | None) -> Principal:
    return Principal(
        subject=subject,
        provider="oidc",
        email=email,
        token_fingerprint="f" * 16,
    )


def test_two_subjects_with_one_verified_email_own_one_portfolio() -> None:
    google = _principal(subject="uid-google", email="Person@Example.Test")
    password = _principal(subject="uid-password", email="person@example.test")

    assert google.owner_key == password.owner_key == "person@example.test"


def test_two_emails_own_two_portfolios() -> None:
    one = _principal(subject="uid-1", email="a@example.test")
    other = _principal(subject="uid-2", email="b@example.test")

    assert one.owner_key != other.owner_key


def test_a_token_with_no_email_falls_back_to_its_subject() -> None:
    """A machine token would otherwise have no portfolio at all."""
    machine = _principal(subject="service-account-7", email=None)

    assert machine.owner_key == "service-account-7"


@pytest.mark.parametrize("email", ["", "   "], ids=["empty_claim", "whitespace_claim"])
def test_a_blank_email_claim_falls_back_rather_than_keying_on_nothing(
    email: str,
) -> None:
    """Found by this test: `"   "` used to become a portfolio keyed on spaces."""
    caller = _principal(subject="uid-9", email=email)

    assert caller.owner_key == "uid-9"
