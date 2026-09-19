"""Scripted HTTP responders for the Gemini adapter tests.

A helper module, not a conftest: these are values the tests import by name
(the same shape as ``tests/unit/auth/rsa_fixture.py``).
"""

from collections.abc import Callable

import httpx
from pydantic import SecretStr

from app.infra.model.gemini_client import GeminiModelClient

BASE_URL = "https://provider.test/v1beta"
KEY = "placeholder-not-a-real-key"  # gitleaks:allow - test fixture
PROVIDER_TEXT = "API key not valid. Please pass a valid API key."
OK_BODY = {"candidates": [{"content": {"parts": [{"text": "answer"}]}}]}

Respond = Callable[[httpx.Request], httpx.Response]


def ok(request: httpx.Request) -> httpx.Response:
    """Answer a well-formed reply."""
    del request
    return httpx.Response(200, json=OK_BODY)


def unavailable(request: httpx.Request) -> httpx.Response:
    """Answer a retryable 503."""
    del request
    return httpx.Response(503)


def rate_limited(request: httpx.Request) -> httpx.Response:
    """Answer a retryable 429."""
    del request
    return httpx.Response(429)


def rejected(request: httpx.Request) -> httpx.Response:
    """Answer a non-retryable 400 carrying provider text."""
    del request
    return httpx.Response(400, text=PROVIDER_TEXT)


def unauthorized(request: httpx.Request) -> httpx.Response:
    """Answer a non-retryable 401."""
    del request
    return httpx.Response(401, text=PROVIDER_TEXT)


def times_out(request: httpx.Request) -> httpx.Response:
    """Fail the way a hung provider does."""
    raise httpx.ConnectTimeout("timed out", request=request)


def not_json(request: httpx.Request) -> httpx.Response:
    """Answer 200 with a body that is not JSON at all."""
    del request
    return httpx.Response(200, text="<html>oops</html>")


def no_candidates(request: httpx.Request) -> httpx.Response:
    """Answer valid JSON that is not a usable Gemini reply."""
    del request
    return httpx.Response(200, json={"candidates": []})


class Stub:
    """Serve scripted responders in order, repeating the last one."""

    def __init__(self, *responders: Respond) -> None:
        self._responders = responders
        self.requests: list[httpx.Request] = []

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        index = min(len(self.requests) - 1, len(self._responders) - 1)
        return self._responders[index](request)


def make_client(stub: Stub, *, max_attempts: int = 3) -> GeminiModelClient:
    """Build a client whose HTTP calls are served by ``stub``."""
    return GeminiModelClient(
        api_key=SecretStr(KEY),
        model="gemini-test",
        base_url=BASE_URL,
        timeout_seconds=7.5,
        max_attempts=max_attempts,
        http=httpx.AsyncClient(transport=httpx.MockTransport(stub)),
    )
