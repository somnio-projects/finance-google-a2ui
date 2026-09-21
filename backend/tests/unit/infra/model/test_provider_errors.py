"""GGU-90 AC-4 — the provider's own words, kept server-side; and retry triage.

Spec 0006 AC-3 keeps provider text away from the caller, and ``test_gemini_
client.py`` still proves that. These tests prove the other half: that the text
is not thrown away either. Both 400s that broke every agent turn were
diagnosable in one line of the response body, and that line went nowhere.
"""

import httpx
import pytest
import structlog

from app.infra.model.provider_errors import (
    MAX_DETAIL_CHARS,
    is_retryable,
    log_provider_failure,
)

PROVIDER_TEXT = "Role 'function' is not supported. Please use a valid role: USER."


def status_error(status: int = 400, text: str = PROVIDER_TEXT) -> httpx.HTTPStatusError:
    """Build the failure a rejected request raises."""
    request = httpx.Request("POST", "https://provider.test/v1beta/models/m:g")
    response = httpx.Response(status, text=text, request=request)
    return httpx.HTTPStatusError("rejected", request=request, response=response)


def test_a_rejection_is_logged_with_the_status_and_the_providers_own_words() -> None:
    with structlog.testing.capture_logs() as logs:
        log_provider_failure(status_error())

    assert logs == [
        {
            "event": "model_provider_rejected",
            "log_level": "warning",
            "status": 400,
            "detail": PROVIDER_TEXT,
        }
    ]


def test_a_very_long_rejection_is_truncated_rather_than_logged_whole() -> None:
    with structlog.testing.capture_logs() as logs:
        log_provider_failure(status_error(text="x" * (MAX_DETAIL_CHARS + 50)))

    assert logs[0]["detail"] == "x" * MAX_DETAIL_CHARS


def test_a_transport_failure_is_logged_by_type_without_the_url_it_names() -> None:
    request = httpx.Request("POST", "https://provider.test/v1beta/models/m:g")

    with structlog.testing.capture_logs() as logs:
        log_provider_failure(httpx.ConnectTimeout("timed out", request=request))

    assert logs == [
        {
            "event": "model_provider_unreachable",
            "log_level": "warning",
            "error": "ConnectTimeout",
        }
    ]


@pytest.mark.parametrize(
    ("exc", "expected"),
    [
        (httpx.ConnectError("down"), True),
        (ValueError("not json"), False),
        (status_error(status=503), True),
        (status_error(status=400), False),
    ],
    ids=[
        "transport_error_is_retryable",
        "parse_error_is_not",
        "server_error_is_retryable",
        "rejected_request_is_not",
    ],
)
def test_is_retryable_classifies_a_failed_attempt(
    exc: Exception, expected: bool
) -> None:
    assert is_retryable(exc) is expected
