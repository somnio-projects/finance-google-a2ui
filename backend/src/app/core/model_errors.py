"""A model provider failure, and what it still cost (spec 0058 §3.2).

Both classes **are** ``DependencyUnavailableError``: same status, same problem
code, same fixed detail, so the client's RFC 9457 answer is exactly what it
was before this module existed. What they add is inward only — the
``outcome`` the turn records, and the ``usage`` the failed call's attempts
billed, so a turn that fails on its third model call still reports the two
it paid for.

**Why out of credit is its own class.** On 2026-11-13 the prepaid Gemini
balance reached zero and every call answered 402. The turn recorded
``model-unavailable`` — the outcome a 503 also produces — so the one failure
that needs a human with a card looked exactly like the one that needs nobody.
Whether our account has money is not something a caller is told (0058 OD-4);
an operator is told through the outcome and the alert on it (infra/0006).
"""

from typing import ClassVar, Final

from app.core.errors import DependencyUnavailableError
from app.core.model_usage import ZERO_USAGE, TokenUsage

#: The outcome of a turn the provider failed for any reason but credit.
MODEL_UNAVAILABLE: Final[str] = "model-unavailable"
#: The outcome of a turn the provider refused because the balance is spent.
MODEL_OUT_OF_CREDIT: Final[str] = "model-out-of-credit"
#: The one detail a caller sees, whichever class is raised. Fixed here, never
#: taken from a docstring: ``AppError`` falls back to ``__doc__``, and the
#: docstrings below describe the cause — which is what a caller must not learn.
MASKED_DETAIL: Final[str] = "model provider unavailable"


class ModelProviderError(DependencyUnavailableError):
    """The model provider failed — transport, status or an unreadable reply."""

    outcome: ClassVar[str] = MODEL_UNAVAILABLE

    def __init__(
        self, detail: str | None = None, *, usage: TokenUsage = ZERO_USAGE
    ) -> None:
        """Carry the masked detail and the usage the failed call billed."""
        super().__init__(detail or MASKED_DETAIL)
        self.usage = usage


class ModelOutOfCreditError(ModelProviderError):
    """The provider answered 402: the prepaid balance is spent.

    Distinct from its parent only inward — the turn records
    ``model-out-of-credit``, which pages an owner (infra/gemini_spend.tf),
    and no retry is attempted because none can succeed until a top-up.
    Outward it is the same masked 503 (spec 0058 OD-4).
    """

    outcome: ClassVar[str] = MODEL_OUT_OF_CREDIT


__all__ = [
    "MASKED_DETAIL",
    "MODEL_OUT_OF_CREDIT",
    "MODEL_UNAVAILABLE",
    "ModelOutOfCreditError",
    "ModelProviderError",
]
