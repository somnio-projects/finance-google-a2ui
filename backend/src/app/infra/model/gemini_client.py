"""Gemini adapter — the only module that holds the API key (spec 0006 AC-2/3).

Built on the already-vendored ``httpx`` rather than a provider SDK (spec 0006
OD-1): no new dependency, no new audit surface, and the same shape as
``app.auth.providers.jwks``.

Two rules govern everything here. ``get_secret_value()`` is called in exactly
one function, on the way into a header — never a query string, never a log,
never an error. And **every** provider failure leaves as
``DependencyUnavailableError`` carrying the same fixed detail: no status line,
no provider message, no URL. The original exception survives as ``__cause__``
for the error reporter, and ``provider_errors.log_provider_failure`` writes
what the provider said to the **server's** log before the mask goes on
(GGU-90 AC-4) — masking outward and recording inward are different decisions,
and having only the first is what made two turn-breaking 400s look like an
unavailable provider.
"""

from collections.abc import Mapping, Sequence

import httpx
from pydantic import SecretStr

from app.core.model import ModelMessage, ModelReply, ToolSpec
from app.core.model_errors import ModelProviderError
from app.core.model_usage import ZERO_USAGE, TokenUsage
from app.infra.model.payload import to_request
from app.infra.model.provider_errors import (
    UNAVAILABLE,
    is_retryable,
    log_provider_failure,
    provider_failure,
)
from app.infra.model.reply import from_response
from app.infra.model.usage import usage_of


class GeminiModelClient:
    """Call Gemini's ``generateContent``, bounded in time and in attempts."""

    def __init__(
        self,
        *,
        api_key: SecretStr,
        model: str,
        base_url: str,
        timeout_seconds: float,
        max_attempts: int,
        http: httpx.AsyncClient | None = None,
    ) -> None:
        """Configure the adapter; ``http`` is injectable for tests."""
        self._api_key = api_key
        self._model = model
        self._url = f"{base_url.rstrip('/')}/models/{model}:generateContent"
        self._timeout = timeout_seconds
        self._max_attempts = max_attempts
        self._http = http

    @property
    def name(self) -> str:
        """The configured model id, as reported to telemetry."""
        return self._model

    def _headers(self) -> dict[str, str]:
        """Build the request headers.

        This is the **only** place the API key is read (spec 0006 AC-2). It
        travels in a header, never in the URL, so it cannot end up in an
        access log or a referrer.
        """
        return {
            "x-goog-api-key": self._api_key.get_secret_value(),
            "content-type": "application/json",
        }

    async def _attempt(
        self, client: httpx.AsyncClient, body: Mapping[str, object]
    ) -> tuple[object, TokenUsage]:
        """POST the body, retrying retryable failures up to the attempt cap.

        The loop ends three ways, all reachable: a success returns, a
        non-retryable failure breaks, an exhausted budget falls through.
        Every attempt's ``usageMetadata`` is summed, failed ones included.

        Raises:
            ModelProviderError: When every permitted attempt failed —
                ``ModelOutOfCreditError`` when the last one was a 402.
        """
        last: BaseException | None = None
        spent = ZERO_USAGE
        attempts = 0
        while attempts < self._max_attempts:
            attempts += 1
            try:
                response = await client.post(
                    self._url, json=dict(body), headers=self._headers()
                )
                spent += usage_of(response)
                response.raise_for_status()
                return response.json(), spent
            except (httpx.HTTPError, ValueError) as exc:
                last = exc
                log_provider_failure(exc)
                if not is_retryable(exc):
                    break
        raise provider_failure(last, usage=spent) from last

    async def _post(self, body: Mapping[str, object]) -> tuple[object, TokenUsage]:
        """Send ``body``, owning the HTTP client when none was injected."""
        client = self._http or httpx.AsyncClient(timeout=self._timeout)
        try:
            return await self._attempt(client, body)
        finally:
            if self._http is None:
                await client.aclose()

    async def generate(
        self,
        *,
        system: str,
        messages: Sequence[ModelMessage],
        tools: Sequence[ToolSpec],
    ) -> ModelReply:
        """Produce the next assistant turn.

        Args:
            system: The system instruction.
            messages: The conversation so far, oldest first.
            tools: The tools the model may call this turn.

        Returns:
            The model's text, any tool calls it asked for, and the usage
            every attempt of the call billed (spec 0058 AC-2).

        Raises:
            ModelProviderError: For every provider failure — timeout,
                transport error, HTTP status, a body that is not JSON, or a
                body that is not a Gemini reply — carrying the usage billed.
        """
        payload, spent = await self._post(
            to_request(system=system, messages=messages, tools=tools)
        )
        try:
            reply = from_response(payload)
        except ValueError as exc:
            raise ModelProviderError(UNAVAILABLE, usage=spent) from exc
        return reply.model_copy(update={"usage": spent})


__all__ = ["UNAVAILABLE", "GeminiModelClient"]
