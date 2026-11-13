"""What a model call spent, in tokens (spec 0058 §3).

A provider-agnostic count, like the rest of ``app.core.model``: the Gemini
adapter fills it from ``usageMetadata``, a scripted or null client leaves it
at zero, and the turn sums it. It is a **count**, never a price — what a token
costs is ``app.core.model_pricing``'s question, and depends on a date.

``billed_calls`` counts attempts whose response carried usage at all, retries
included (0058 OD-3). It is what tells "the model answered for free" (a
scripted client: zero calls) apart from "the model answered and we have no
price for it" (calls > 0, unknown model).
"""

from typing import Final, Self

from pydantic import BaseModel, ConfigDict, Field


class TokenUsage(BaseModel):
    """Token counts spent by one or more model calls."""

    model_config = ConfigDict(frozen=True)

    prompt: int = Field(default=0, ge=0, description="Input tokens, cached included.")
    cached: int = Field(
        default=0, ge=0, description="The part of ``prompt`` served from cache."
    )
    candidates: int = Field(default=0, ge=0, description="Output tokens.")
    thoughts: int = Field(
        default=0, ge=0, description="Thinking tokens; billed as output."
    )
    total: int = Field(default=0, ge=0, description="The provider's own total.")
    billed_calls: int = Field(
        default=0, ge=0, description="Attempts that reported usage."
    )

    def __add__(self, other: Self) -> Self:
        """Return the field-wise sum of two usages."""
        return self.model_copy(
            update={
                name: getattr(self, name) + getattr(other, name)
                for name in type(self).model_fields
            }
        )


#: Nothing spent. The default of every reply and every turn.
ZERO_USAGE: Final[TokenUsage] = TokenUsage()


__all__ = ["ZERO_USAGE", "TokenUsage"]
