"""When the model should reach for a projection — and when it should not.

The catalog already teaches the model *what* every view shows: ``summary`` is
one line of purpose, and ``prompt.py`` prints it with the view's declared
options. That is enough to fill a payload and not enough to **choose** one,
which is the decision the model actually gets wrong: asked why a number moved
it reaches for the breakdown of what is held now, because both are "about the
portfolio" and nothing in the catalog separates them.

The design catalog (GGU-53) writes that separation down as an explicit do/don't
pair per component, and it is better than what this backend generated, so the
shape is taken from it: one sentence for the question a view answers, one for
the question it does not — naming the view that does instead. Published from
the registry like everything else (ADR-K D-14), so a view teaches the model by
being registered and no prompt is hand-maintained anywhere.

**Optional on purpose.** A projection whose design page was never exported
carries no guidance rather than guidance this backend invented: the catalog is
a contract with design, and a plausible sentence written here would be
indistinguishable from one a designer approved. ``None`` is the honest answer
until the page exists (the same rule the compliance corpus follows for
"planned").
"""

from typing import Final

from pydantic import BaseModel, ConfigDict, Field

#: Bound on each sentence. Long enough for the designer's own wording, short
#: enough that the assembled prompt stays a catalog rather than a manual.
MAX_SENTENCE: Final[int] = 400


class Guidance(BaseModel):
    """The do/don't pair that teaches the model when to pick a projection."""

    model_config = ConfigDict(frozen=True)

    use_when: str = Field(
        max_length=MAX_SENTENCE,
        description=(
            "The question this view answers, in the words the model is taught. "
            "Reads as the object of 'Use this view when ...'."
        ),
        examples=[
            "the user asks why a value changed and the answer decomposes into "
            "signed contributions that sum to a net delta"
        ],
    )
    avoid_when: str = Field(
        max_length=MAX_SENTENCE,
        description=(
            "The question this view does **not** answer, naming the view that "
            "does. Reads as the object of 'Do not use this view for ...'."
        ),
        examples=[
            "a breakdown of what is held now — `holdings.allocation.v1` answers that"
        ],
    )


__all__ = ["MAX_SENTENCE", "Guidance"]
